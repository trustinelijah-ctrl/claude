import AVFoundation
import Observation
import Speech

/// Say it aloud and see it written: on-device speech recognition in the
/// exercise's language, with the elapsed time for a pace note. The web asks
/// the learner to type roughly what they said; the phone just listens.
@MainActor
@Observable
final class SpeechCapture {
    enum State: Equatable { case idle, requesting, listening, denied, unavailable }
    private(set) var state: State = .idle
    private(set) var transcript = ""
    private(set) var elapsed: TimeInterval = 0
    private(set) var level: Float = 0

    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private var request: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var task: SFSpeechRecognitionTask?
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var started: Date?
    @ObservationIgnored private var onText: ((String) -> Void)?
    @ObservationIgnored private var prefix = ""

    var isListening: Bool { state == .listening }

    /// Starts listening; `onText` receives the existing text plus what has been heard so far.
    func start(lang: Lang, existing: String, limit: TimeInterval? = nil, onText: @escaping (String) -> Void) {
        guard state != .listening else { return }
        self.onText = onText
        prefix = existing.trimmingCharacters(in: .whitespacesAndNewlines)
        transcript = ""
        state = .requesting
        SFSpeechRecognizer.requestAuthorization { status in
            Task { @MainActor in
                guard status == .authorized else { self.state = .denied; return }
                AVAudioApplication.requestRecordPermission { ok in
                    Task { @MainActor in
                        guard ok else { self.state = .denied; return }
                        self.begin(lang: lang, limit: limit)
                    }
                }
            }
        }
    }

    private func begin(lang: Lang, limit: TimeInterval?) {
        guard let rec = SFSpeechRecognizer(locale: lang.locale), rec.isAvailable else { state = .unavailable; return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            let req = SFSpeechAudioBufferRecognitionRequest()
            req.shouldReportPartialResults = true
            if rec.supportsOnDeviceRecognition { req.requiresOnDeviceRecognition = true }
            req.addsPunctuation = true
            request = req
            let input = engine.inputNode
            let fmt = input.outputFormat(forBus: 0)
            input.removeTap(onBus: 0)
            input.installTap(onBus: 0, bufferSize: 1024, format: fmt, block: Self.tap(req) { [weak self] lvl in
                Task { @MainActor in self?.level = lvl }
            })
            engine.prepare()
            try engine.start()
            task = rec.recognitionTask(with: req, resultHandler: Self.handler { [weak self] text, finished in
                Task { @MainActor in
                    guard let self else { return }
                    if let text {
                        self.transcript = text
                        let joined = [self.prefix, text].filter { !$0.isEmpty }.joined(separator: " ")
                        self.onText?(joined)
                    }
                    if finished { self.stop() }
                }
            })
            started = Date()
            elapsed = 0
            state = .listening
            timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self, let s = self.started else { return }
                    self.elapsed = Date().timeIntervalSince(s)
                    if let limit, self.elapsed >= limit + 15 { self.stop() }
                }
            }
        } catch {
            state = .unavailable
            cleanup()
        }
    }

    // Built outside the main actor: both run on audio/recognition threads.
    nonisolated private static func tap(_ req: SFSpeechAudioBufferRecognitionRequest,
                                        level: @escaping @Sendable (Float) -> Void) -> AVAudioNodeTapBlock {
        { buf, _ in
            req.append(buf)
            guard let ch = buf.floatChannelData?[0] else { return }
            var sum: Float = 0
            for i in 0..<Int(buf.frameLength) { sum += ch[i] * ch[i] }
            level(min(1, sqrt(sum / Float(max(1, buf.frameLength))) * 12))
        }
    }
    nonisolated private static func handler(_ out: @escaping @Sendable (String?, Bool) -> Void) -> (SFSpeechRecognitionResult?, Error?) -> Void {
        { result, error in out(result?.bestTranscription.formattedString, error != nil || (result?.isFinal ?? false)) }
    }

    func stop() {
        guard state == .listening || state == .requesting else { return }
        request?.endAudio()
        cleanup()
        state = .idle
    }

    private func cleanup() {
        timer?.invalidate(); timer = nil
        if engine.isRunning { engine.stop() }
        engine.inputNode.removeTap(onBus: 0)
        task?.finish(); task = nil
        request = nil
        level = 0
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
