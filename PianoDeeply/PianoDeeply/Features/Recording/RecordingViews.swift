import SwiftUI
import SwiftData
import PianoCore

/// Record button with the permission flow: explain first, then ask, and if
/// the answer is no, say so plainly and leave everything else working.
struct RecordControl: View {
    /// Identifies this control so only it shows Stop for its own take.
    let owner: String
    /// Title stored on the recording ("Cold pass: Bars 9–12").
    let title: String
    var onFinished: (Recording) -> Void = { _ in }

    @Environment(AudioRecorder.self) private var recorder
    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL
    @State private var showingExplanation = false
    @State private var errorText: String?

    private var isMine: Bool { recorder.isRecording && recorder.ownerID == owner }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isMine {
                Button(action: stop) {
                    HStack(spacing: 10) {
                        Image(systemName: "stop.fill")
                        Text("Stop recording")
                        if let start = recorder.startedAt {
                            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                                Text(SessionClock.format(timeline.date.timeIntervalSince(start)))
                                    .monospacedDigit()
                            }
                        }
                    }
                }
                .buttonStyle(.secondary)
                .overlay(alignment: .leading) {
                    Circle().fill(.red).frame(width: 8, height: 8).padding(.leading, 12).accessibilityHidden(true)
                }
            } else if recorder.isRecording {
                Text("Another recording is running. Stop it first.")
                    .font(.footnote)
                    .foregroundStyle(Palette.inkSoft)
            } else if recorder.permission == .denied {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Microphone access is off", systemImage: "mic.slash")
                        .font(.subheadline.weight(.semibold))
                    Text("Recording isn't available, and everything else works as usual. You can turn the microphone on in Settings.")
                        .font(.footnote)
                        .foregroundStyle(Palette.inkSoft)
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                    .font(.footnote.weight(.semibold))
                }
            } else {
                Button(action: tapRecord) {
                    Label("Record", systemImage: "record.circle")
                }
                .buttonStyle(.secondary)
            }
            if let errorText {
                Text(errorText).font(.footnote).foregroundStyle(Palette.inkSoft)
            }
        }
        .sheet(isPresented: $showingExplanation) {
            MicrophoneExplanation {
                showingExplanation = false
                Task {
                    if await recorder.requestPermission() { start() }
                }
            } onCancel: {
                showingExplanation = false
            }
            .presentationDetents([.medium, .large])
        }
        .onAppear { recorder.refreshPermission() }
        // No onDisappear stop: rows in a Form disappear when scrolled away.
        // The hosting screen calls `recorder.stop(ifOwnedBy:)` when it closes.
    }

    private func tapRecord() {
        recorder.refreshPermission()
        switch recorder.permission {
        case .granted: start()
        case .undetermined: showingExplanation = true
        case .denied: break
        }
    }

    private func start() {
        do {
            errorText = nil
            try recorder.start(owner: owner) { [context, title, onFinished] finished in
                let recording = Recording(fileName: finished.fileName, duration: finished.duration, title: title)
                context.insert(recording)
                onFinished(recording)
                try? context.save()
            }
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func stop() {
        recorder.stop()
    }
}

struct MicrophoneExplanation: View {
    var onContinue: () -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: "mic")
                .font(.title)
                .foregroundStyle(Palette.forest)
                .accessibilityHidden(true)
            Text("Recording your playing")
                .font(.displayTitle)
            Text("The microphone is only on while you're recording. Files stay on this iPhone; nothing is uploaded.")
            Text("The app can't judge notes, tone, or accuracy from audio. Recordings are for you to listen back and compare.")
                .foregroundStyle(Palette.inkSoft)
            Spacer(minLength: 0)
            Button("Continue", action: onContinue).buttonStyle(.primary)
            Button("Not now", action: onCancel)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .padding(24)
        .background(Palette.canvas.ignoresSafeArea())
    }
}

/// Play/stop, with honest states for a missing or unreadable file.
struct PlayButton: View {
    let recording: Recording
    var label: String? = nil
    @Environment(AudioPlayer.self) private var player

    var body: some View {
        if !recording.fileExists {
            Label("Audio file missing", systemImage: "exclamationmark.triangle")
                .font(.footnote)
                .foregroundStyle(Palette.inkSoft)
        } else if player.unplayableIDs.contains(recording.id) {
            Label("This file can't be played", systemImage: "exclamationmark.triangle")
                .font(.footnote)
                .foregroundStyle(Palette.inkSoft)
        } else {
            let playing = player.isPlaying(recording)
            Button { player.toggle(recording) } label: {
                Label(label ?? (playing ? "Stop" : "Play"), systemImage: playing ? "stop.fill" : "play.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(minHeight: 44)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(playing ? "Stop \(recording.displayTitle)" : "Play \(recording.displayTitle)")
        }
    }
}

struct RecordingRow: View {
    let recording: Recording

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Label(recording.displayTitle, systemImage: "waveform")
                    .font(.body.weight(.medium))
                Spacer()
                Text(Duration.seconds(recording.duration).formatted(.time(pattern: .minuteSecond)))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(Palette.inkSoft)
            }
            HStack(spacing: 16) {
                PlayButton(recording: recording)
                if recording.fileExists {
                    ShareLink(item: recording.url) {
                        Label("Share audio", systemImage: "square.and.arrow.up")
                            .font(.subheadline)
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
    }
}

/// Holds the take made on a screen. A class, so a save that first stops the
/// recorder sees the new recording immediately.
@Observable
final class TakeHolder {
    var recording: Recording?
}

/// Minimal numeric field for a user-entered tempo. Blank means "not measured".
struct TempoField: View {
    @Binding var text: String

    var body: some View {
        HStack {
            Text("Tempo")
            Spacer()
            TextField("optional", text: $text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 110)
            Text("bpm").foregroundStyle(Palette.inkSoft)
        }
    }

    static func parse(_ text: String) -> Int? {
        guard let value = Int(text.trimmingCharacters(in: .whitespaces)), (10...400).contains(value) else { return nil }
        return value
    }
}

#if DEBUG
#Preview("Microphone explanation") {
    MicrophoneExplanation(onContinue: {}, onCancel: {})
}

#Preview("No recording permission") {
    Form {
        RecordControl(owner: "preview", title: "Preview")
    }
    // Set closest to the view so it wins over previewEnvironment's recorder.
    .environment(AudioRecorder(previewPermission: .denied))
    .previewEnvironment(.fresh)
}
#endif
