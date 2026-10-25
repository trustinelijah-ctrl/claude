import AVFoundation
import AudioToolbox
import os

enum SoundEffect: String, CaseIterable {
    case place, placeLight, placeHeavy, capture, pickup, invalid, ui, promotion, check, checkmate, draw, reset
    case clockPress, clockTick, topple, notch
}

/// A sound bed under the game, for 64 Pro.
enum Ambience: String, CaseIterable, Identifiable {
    case off, rain, storm, fire, cafe, sea, forest, night
    var id: String { rawValue }
    var title: String {
        switch self {
        case .off: return "Off"
        case .rain: return "Rain"
        case .storm: return "Storm"
        case .fire: return "Fireplace"
        case .cafe: return "Café"
        case .sea: return "Sea"
        case .forest: return "Forest"
        case .night: return "Night"
        }
    }
    var symbol: String {
        switch self {
        case .off: return "speaker.slash.fill"
        case .rain: return "cloud.rain.fill"
        case .storm: return "cloud.bolt.rain.fill"
        case .fire: return "flame.fill"
        case .cafe: return "cup.and.saucer.fill"
        case .sea: return "water.waves"
        case .forest: return "leaf.fill"
        case .night: return "moon.stars.fill"
        }
    }
    fileprivate var file: String? { self == .off ? nil : "ambience_\(rawValue)" }

    /// The scenes whose recordings are in the app (and Off).
    static let available: [Ambience] = allCases.filter { a in
        guard let f = a.file else { return true }
        return ["m4a", "caf", "wav", "aac"].contains { Bundle.main.url(forResource: f, withExtension: $0) != nil }
    }
}

/// Low-latency playback of the sound palette.
///
/// Every sound is decoded into memory at launch and played through a fixed pool of player
/// nodes on one AVAudioEngine, so nothing is created or decoded during play. Sounds can be
/// scheduled a few milliseconds ahead on the audio clock, which is how a placement sound
/// lands on the exact frame a piece settles. All engine work happens on one serial queue.
final class AudioManager: @unchecked Sendable {
    private let queue = DispatchQueue(label: "table.audio", qos: .userInteractive)
    private let log = Logger(subsystem: "app.table.chess", category: "audio")

    private var engine = AVAudioEngine()
    private var submix = AVAudioMixerNode()
    private var limiter: AVAudioUnitEffect?
    private var voices: [Voice] = []
    /// The ambience bed: one looping stereo player under the move sounds.
    private var ambienceNode = AVAudioPlayerNode()
    private var ambienceBuffers: [Ambience: AVAudioPCMBuffer] = [:]
    private var ambience: Ambience = .off
    private var fadeToken = 0
    private var ambienceVolume: Float = 0.35
    /// Ambience has its own level, independent of the move sounds; it sits well under them.
    private var ambienceTarget: Float { Self.loudness(ambienceVolume) * 0.7 }
    private static let stereo = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2)!
    private var library: [SoundEffect: [AVAudioPCMBuffer]] = [:]
    private var lastPick: [SoundEffect: Int] = [:]
    private var ready = false
    private var enabled = true
    private var volume: Float = 0.35
    /// Sound is the point of 64, so by default it plays even with the silent switch on.
    private var playsInSilentMode = true

    private static let voiceCount = 12
    private static let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1)!
    /// Small playback-rate variations applied to every sample so repeats never sound identical.
    private static let rates: [Double] = [0.972, 0.988, 1.0, 1.012, 1.028]

    private final class Voice {
        let node = AVAudioPlayerNode()
        var busyUntil: UInt64 = 0
    }

    init() {
        queue.async { self.setUp() }
        let nc = NotificationCenter.default
        nc.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: nil) { [weak self] note in
            guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: raw), type == .ended else { return }
            self?.resume()
        }
        nc.addObserver(forName: .AVAudioEngineConfigurationChange, object: nil, queue: nil) { [weak self] _ in
            self?.resume()
        }
        nc.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: nil) { [weak self] _ in
            self?.queue.async { self?.rebuild() }
        }
    }

    /// The slider is perceptual: half way sounds about half as loud, not a hair quieter.
    private static func loudness(_ v: Float) -> Float { pow(v, 1.6) }

    // MARK: Public

    func setPlaysInSilentMode(_ on: Bool) {
        queue.async {
            guard on != self.playsInSilentMode else { return }
            self.playsInSilentMode = on
            self.configureSession()
        }
    }

    func setEnabled(_ on: Bool) {
        queue.async {
            self.enabled = on
            self.applyAmbience()
        }
    }

    func setAmbienceVolume(_ value: Double) {
        queue.async {
            self.ambienceVolume = Float(max(0, min(1, value)))
            if self.ambience != .off, self.ambienceNode.isPlaying {
                self.fadeToken += 1
                self.ambienceNode.volume = self.ambienceTarget
            }
        }
    }

    /// Fades the ambience bed over to `choice` (or out, for `.off`).
    func setAmbience(_ choice: Ambience) {
        queue.async {
            guard choice != self.ambience else { return }
            self.ambience = choice
            self.applyAmbience()
        }
    }

    func setVolume(_ value: Double) {
        queue.async {
            self.volume = Float(max(0, min(1, value)))
            self.submix.outputVolume = Self.loudness(self.volume)
        }
    }

    /// Restarts audio after an interruption, a route change, or returning to the foreground.
    func resume() {
        queue.async { self.startEngine() }
    }

    /// Plays a sound, optionally scheduled `delay` seconds from now on the audio clock.
    /// - Parameters:
    ///   - gain: linear gain for this instance (0...1).
    ///   - pan: stereo position in screen space, -1 (left edge) to 1 (right edge).
    func play(_ effect: SoundEffect, delay: TimeInterval = 0, gain: Float = 1, pan: Float = 0) {
        let requested = mach_absolute_time()
        queue.async {
            guard self.ready, self.enabled, self.volume > 0, self.engine.isRunning,
                  let buffer = self.pick(effect) else { return }
            let start = requested + AVAudioTime.hostTime(forSeconds: max(0, delay))
            let voice = self.voices.first { $0.busyUntil <= start } ?? self.voices.min { $0.busyUntil < $1.busyUntil }!
            let length = Double(buffer.frameLength) / buffer.format.sampleRate
            voice.node.volume = gain
            voice.node.pan = max(-1, min(1, pan))
            voice.node.scheduleBuffer(buffer, at: AVAudioTime(hostTime: start), options: [], completionHandler: nil)
            voice.busyUntil = start + AVAudioTime.hostTime(forSeconds: length + 0.01)
        }
    }

    // MARK: Setup

    private func setUp() {
        configureSession()
        loadLibrary()
        buildGraph()
        startEngine()
        ready = true
        applyAmbience()
    }

    /// Playback (heard with the silent switch on) or ambient (silenced by it); either way it
    /// mixes with whatever music is playing at the table.
    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(playsInSilentMode ? .playback : .ambient, mode: .default, options: [.mixWithOthers])
            try session.setPreferredIOBufferDuration(0.005)
            try session.setActive(true)
        } catch {
            log.error("Audio session: \(error.localizedDescription)")
        }
    }

    private func rebuild() {
        engine.stop()
        engine = AVAudioEngine()
        // Every node belongs to one engine: build fresh ones for the new engine.
        submix = AVAudioMixerNode()
        voices = []
        limiter = nil
        ambienceNode = AVAudioPlayerNode()
        buildGraph()
        startEngine()
    }

    private func buildGraph() {
        let out = engine.outputNode.outputFormat(forBus: 0)
        let stereo = AVAudioFormat(standardFormatWithSampleRate: out.sampleRate > 0 ? out.sampleRate : 48_000, channels: 2)!

        engine.attach(submix)
        let limiterDesc = AudioComponentDescription(componentType: kAudioUnitType_Effect,
                                                    componentSubType: kAudioUnitSubType_PeakLimiter,
                                                    componentManufacturer: kAudioUnitManufacturer_Apple,
                                                    componentFlags: 0, componentFlagsMask: 0)
        let limiter = AVAudioUnitEffect(audioComponentDescription: limiterDesc)
        engine.attach(limiter)
        self.limiter = limiter

        for _ in 0..<Self.voiceCount {
            let v = Voice()
            engine.attach(v.node)
            engine.connect(v.node, to: submix, format: Self.format)
            voices.append(v)
        }
        engine.attach(ambienceNode)
        // Straight to the main mix: the effects volume and switch don't touch it.
        engine.connect(ambienceNode, to: engine.mainMixerNode, format: Self.stereo)
        engine.connect(submix, to: limiter, format: stereo)
        engine.connect(limiter, to: engine.mainMixerNode, format: stereo)
        submix.outputVolume = Self.loudness(volume)
        engine.prepare()
    }

    private func startEngine() {
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            if !engine.isRunning { try engine.start() }
            for v in voices {
                v.busyUntil = 0
                if !v.node.isPlaying { v.node.play() }
            }
            if ready, ambience != .off, !ambienceNode.isPlaying { applyAmbience() }
        } catch {
            log.error("Audio engine start: \(error.localizedDescription)")
        }
    }

    // MARK: Ambience

    private func applyAmbience() {
        guard ready else { return }
        guard let buffer = ambienceBuffer(ambience), engine.isRunning else {
            fade(to: 0, over: 0.8, thenStop: true)
            return
        }
        fadeToken += 1
        ambienceNode.stop()
        ambienceNode.volume = 0
        ambienceNode.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
        ambienceNode.play()
        fade(to: ambienceTarget, over: 1.6)
    }

    private func fade(to target: Float, over seconds: Double, thenStop: Bool = false) {
        fadeToken += 1
        let token = fadeToken
        let start = ambienceNode.volume
        let steps = 30
        for i in 1...steps {
            queue.asyncAfter(deadline: .now() + seconds * Double(i) / Double(steps)) {
                guard token == self.fadeToken else { return }
                let p = Float(i) / Float(steps)
                self.ambienceNode.volume = start + (target - start) * p * p * (3 - 2 * p)
                if i == steps && thenStop { self.ambienceNode.stop() }
            }
        }
    }

    private func ambienceBuffer(_ choice: Ambience) -> AVAudioPCMBuffer? {
        if let b = ambienceBuffers[choice] { return b }
        guard let name = choice.file, let url = Self.url(for: name),
              let buffer = Self.decode(url, to: Self.stereo) else { return nil }
        // Loops are made a whole number of seconds long; an encoder may pad the end a little.
        let seconds = floor(Double(buffer.frameLength) / buffer.format.sampleRate)
        if seconds >= 1 { buffer.frameLength = AVAudioFrameCount(seconds * buffer.format.sampleRate) }
        ambienceBuffers[choice] = buffer
        return buffer
    }

    // MARK: Library

    private func loadLibrary() {
        for effect in SoundEffect.allCases {
            var buffers: [AVAudioPCMBuffer] = []
            var index = 1
            while let url = Self.url(for: "\(effect.rawValue)_\(index)") {
                if let base = Self.decode(url) {
                    buffers += Self.rates.compactMap { Self.resample(base, rate: $0) }
                }
                index += 1
            }
            if buffers.isEmpty { log.error("Missing sound \(effect.rawValue)") }
            library[effect] = buffers
        }
    }

    /// Picks a variation, never the same one twice in a row.
    private func pick(_ effect: SoundEffect) -> AVAudioPCMBuffer? {
        guard let all = library[effect], !all.isEmpty else { return nil }
        guard all.count > 1 else { return all[0] }
        var i = Int.random(in: 0..<all.count)
        if i == lastPick[effect] { i = (i + 1 + Int.random(in: 0..<(all.count - 1))) % all.count }
        lastPick[effect] = i
        return all[i]
    }

    private static func url(for name: String) -> URL? {
        for ext in ["wav", "caf", "aif", "m4a"] {
            if let u = Bundle.main.url(forResource: name, withExtension: ext) { return u }
            if let u = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Sounds") { return u }
        }
        return nil
    }

    /// Decodes a file into a 48 kHz float buffer (mono unless asked otherwise), converting if a
    /// replacement recording differs.
    private static func decode(_ url: URL, to format: AVAudioFormat = AudioManager.format) -> AVAudioPCMBuffer? {
        guard let file = try? AVAudioFile(forReading: url),
              let raw = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)),
              (try? file.read(into: raw)) != nil else { return nil }
        if raw.format == format { return raw }
        guard let converter = AVAudioConverter(from: raw.format, to: format) else { return nil }
        let ratio = format.sampleRate / raw.format.sampleRate
        guard let out = AVAudioPCMBuffer(pcmFormat: format,
                                         frameCapacity: AVAudioFrameCount(Double(raw.frameLength) * ratio) + 1024) else { return nil }
        var fed = false
        var error: NSError?
        converter.convert(to: out, error: &error) { _, status in
            if fed { status.pointee = .endOfStream; return nil }
            fed = true
            status.pointee = .haveData
            return raw
        }
        return error == nil ? out : nil
    }

    /// Linear-interpolation resample: rate > 1 plays higher and shorter, like a lighter piece.
    private static func resample(_ src: AVAudioPCMBuffer, rate: Double) -> AVAudioPCMBuffer? {
        if rate == 1 { return src }
        let n = Int(src.frameLength)
        let m = Int(Double(n) / rate)
        guard let dst = AVAudioPCMBuffer(pcmFormat: src.format, frameCapacity: AVAudioFrameCount(m)),
              let s = src.floatChannelData?[0], let d = dst.floatChannelData?[0] else { return nil }
        for i in 0..<m {
            let x = Double(i) * rate
            let j = Int(x)
            let f = Float(x - Double(j))
            let a = s[min(j, n - 1)], b = s[min(j + 1, n - 1)]
            d[i] = a + (b - a) * f
        }
        dst.frameLength = AVAudioFrameCount(m)
        return dst
    }
}
