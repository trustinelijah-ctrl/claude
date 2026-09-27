import AVFoundation
import Foundation
import Observation
import SwiftData

/// Where recordings live: Documents/Recordings/<uuid>.m4a, on this device only.
enum RecordingStore {
    static var directory: URL {
        URL.documentsDirectory.appending(path: "Recordings", directoryHint: .isDirectory)
    }

    static func ensureDirectory() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    static func url(for fileName: String) -> URL {
        directory.appending(path: fileName, directoryHint: .notDirectory)
    }

    static func fileExists(_ fileName: String) -> Bool {
        !fileName.isEmpty && FileManager.default.fileExists(atPath: url(for: fileName).path(percentEncoded: false))
    }

    /// Removes the audio file and its record together. A file that is already
    /// missing is not an error; the record still goes.
    static func delete(_ recording: Recording, in context: ModelContext) {
        try? FileManager.default.removeItem(at: recording.url)
        context.delete(recording)
    }
}

/// Microphone recording. Permission is only requested when the user taps
/// Record, after the app has explained why (see `RecordControl`).
@Observable
final class AudioRecorder: NSObject, AVAudioRecorderDelegate {
    enum Permission { case undetermined, granted, denied }

    struct Finished {
        let fileName: String
        let duration: TimeInterval
    }

    enum RecorderError: LocalizedError {
        case couldNotStart
        var errorDescription: String? { "Recording couldn't start. Another app may be using the microphone." }
    }

    private(set) var permission: Permission = .undetermined
    private(set) var isRecording = false
    private(set) var startedAt: Date?
    /// Which view started the current recording, so only that one shows Stop.
    private(set) var ownerID: String?

    @ObservationIgnored private var recorder: AVAudioRecorder?
    @ObservationIgnored private var fileName: String?
    @ObservationIgnored private var onFinish: ((Finished) -> Void)?
    @ObservationIgnored private var interruptionObserver: NSObjectProtocol?
    @ObservationIgnored private var pinnedPermission: Permission?

    override init() {
        super.init()
        refreshPermission()
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { [weak self] note in
            self?.handleInterruption(note)
        }
    }

    deinit {
        if let interruptionObserver { NotificationCenter.default.removeObserver(interruptionObserver) }
    }

    #if DEBUG
    /// Previews only: shows a permission state without asking the system.
    convenience init(previewPermission: Permission) {
        self.init()
        pinnedPermission = previewPermission
        permission = previewPermission
    }
    #endif

    func refreshPermission() {
        if let pinnedPermission {
            permission = pinnedPermission
            return
        }
        switch AVAudioApplication.shared.recordPermission {
        case .granted: permission = .granted
        case .denied: permission = .denied
        default: permission = .undetermined
        }
    }

    /// Shows the system prompt. Call only after the user has read the
    /// explanation and chosen to continue.
    func requestPermission() async -> Bool {
        let granted = await AVAudioApplication.requestRecordPermission()
        await MainActor.run { refreshPermission() }
        return granted
    }

    /// `onFinish` runs whenever the take ends, whoever stops it, so a take is
    /// saved even if the screen that started it has closed.
    func start(owner: String, onFinish: @escaping (Finished) -> Void) throws {
        guard !isRecording else { return }
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothA2DP])
        try session.setActive(true)
        try RecordingStore.ensureDirectory()

        let name = "\(UUID().uuidString).m4a"
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]
        let recorder = try AVAudioRecorder(url: RecordingStore.url(for: name), settings: settings)
        recorder.delegate = self
        guard recorder.record() else { throw RecorderError.couldNotStart }

        self.recorder = recorder
        self.fileName = name
        self.ownerID = owner
        self.onFinish = onFinish
        self.startedAt = .now
        self.isRecording = true
    }

    /// Stops and returns the finished file, or nil if nothing was recording.
    @discardableResult
    func stop() -> Finished? {
        guard let recorder, let fileName else { return nil }
        let duration = recorder.currentTime
        recorder.stop()
        let handler = onFinish
        self.recorder = nil
        self.fileName = nil
        self.ownerID = nil
        self.onFinish = nil
        self.startedAt = nil
        self.isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        let finished = Finished(fileName: fileName, duration: duration)
        handler?(finished)
        return finished
    }

    /// Screens that host a Record button call this when they close.
    func stop(ifOwnedBy owner: String) {
        if isRecording, ownerID == owner { stop() }
    }

    /// A phone call pauses the recorder; carry on afterwards instead of
    /// leaving a recording that silently stopped.
    private func handleInterruption(_ note: Notification) {
        guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw),
              type == .ended, isRecording, let recorder, !recorder.isRecording else { return }
        try? AVAudioSession.sharedInstance().setActive(true)
        recorder.record()
    }
}

/// Plays one recording at a time.
@Observable
final class AudioPlayer: NSObject, AVAudioPlayerDelegate {
    private(set) var playingID: UUID?
    /// Recordings whose file exists but couldn't be played (for example a
    /// recording cut off when the app was closed mid-take).
    private(set) var unplayableIDs: Set<UUID> = []

    @ObservationIgnored private var player: AVAudioPlayer?

    func isPlaying(_ recording: Recording) -> Bool { playingID == recording.id }

    func toggle(_ recording: Recording) {
        if playingID == recording.id {
            stop()
        } else {
            play(recording)
        }
    }

    func play(_ recording: Recording) {
        stop()
        guard recording.fileExists else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            if session.category != .playAndRecord {
                try session.setCategory(.playback, mode: .default)
            }
            try session.setActive(true)
            let player = try AVAudioPlayer(contentsOf: recording.url)
            player.delegate = self
            guard player.play() else { throw CocoaError(.fileReadCorruptFile) }
            self.player = player
            playingID = recording.id
        } catch {
            unplayableIDs.insert(recording.id)
        }
    }

    func stop() {
        player?.stop()
        player = nil
        playingID = nil
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.player === player else { return }
            self.player = nil
            self.playingID = nil
        }
    }
}
