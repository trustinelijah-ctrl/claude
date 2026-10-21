import AVFoundation
import AudioToolbox
import os

enum SoundEffect: String, CaseIterable {
    case place, capture, pickup, invalid, ui, promotion, check, checkmate, draw, reset
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
    private let submix = AVAudioMixerNode()
    private var limiter: AVAudioUnitEffect?
    private var voices: [Voice] = []
    private var library: [SoundEffect: [AVAudioPCMBuffer]] = [:]
    private var lastPick: [SoundEffect: Int] = [:]
    private var ready = false
    private var enabled = true
    private var volume: Float = 0.5

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

    func setEnabled(_ on: Bool) {
        queue.async { self.enabled = on }
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
        let session = AVAudioSession.sharedInstance()
        do {
            // Ambient: respects the silent setting and mixes with whatever music is playing at the table.
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setPreferredIOBufferDuration(0.005)
            try session.setActive(true)
        } catch {
            log.error("Audio session: \(error.localizedDescription)")
        }
        loadLibrary()
        buildGraph()
        startEngine()
        ready = true
    }

    private func rebuild() {
        engine.stop()
        engine = AVAudioEngine()
        voices = []
        limiter = nil
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
        } catch {
            log.error("Audio engine start: \(error.localizedDescription)")
        }
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

    /// Decodes a file into a mono 48 kHz float buffer, converting if a replacement recording differs.
    private static func decode(_ url: URL) -> AVAudioPCMBuffer? {
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
