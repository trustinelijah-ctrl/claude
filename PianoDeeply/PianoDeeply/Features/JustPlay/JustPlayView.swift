import SwiftUI
import SwiftData
import PianoCore

/// Opening the piano. No goals, no errors, no prompts to log anything. The
/// timer and recording are there only if you want them.
struct JustPlayView: View {
    let session: PracticeSession

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AudioRecorder.self) private var recorder
    @AppStorage("justPlayShowsTimer") private var showsTimer = false
    @ScaledMetric(relativeTo: .largeTitle) private var timerSize: CGFloat = 48

    private var recordingOwner: String { "justplay-\(session.id)" }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer(minLength: 40)
                KeyboardMotif()
                VStack(spacing: 12) {
                    Text("Just play.")
                        .font(.display)
                    Text("Nothing to get right. Close this when you're done.")
                        .font(.title3)
                        .foregroundStyle(Palette.inkSoft)
                        .multilineTextAlignment(.center)
                }

                if showsTimer {
                    TimelineView(.periodic(from: .now, by: 1)) { timeline in
                        Text(SessionClock.format(session.elapsed(at: timeline.date)))
                            .font(.system(size: timerSize, weight: .light, design: .serif))
                            .monospacedDigit()
                            .foregroundStyle(Palette.inkSoft)
                    }
                    .transition(.opacity)
                }

                VStack(spacing: 12) {
                    Toggle("Show timer", isOn: $showsTimer.animation())
                        .frame(minHeight: 44)
                    RecordControl(owner: recordingOwner,
                                  title: "Just play, \(session.startedAt.formatted(date: .abbreviated, time: .shortened))") { made in
                        made.session = session
                    }
                }
                .frame(maxWidth: 420)

                Button("Done") {
                    recorder.stop(ifOwnedBy: recordingOwner)
                    session.finish()
                    try? context.save()
                    dismiss()
                }
                .buttonStyle(.primary)
                .frame(maxWidth: 420)
            }
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .background(Palette.canvas.ignoresSafeArea())
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            recorder.stop(ifOwnedBy: recordingOwner)
        }
    }
}

#if DEBUG
#Preview("Just play") {
    let container = PreviewData.container(.fresh)
    let session = PracticeSession(kind: .justPlay)
    container.mainContext.insert(session)
    return JustPlayView(session: session)
        .previewEnvironment(container: container)
}
#endif
