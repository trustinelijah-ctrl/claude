import SwiftUI
import SwiftData
import PianoCore

/// The running session. Leaving (Minimize), backgrounding, or quitting the
/// app doesn't stop or lose it: time comes from stored timestamps and every
/// field writes straight to the saved session.
struct ActiveSessionView: View {
    @Bindable var session: PracticeSession

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AudioRecorder.self) private var recorder
    @State private var feedback: ExperimentFeedback?
    @State private var confirmingDiscard = false

    private var recordingOwner: String { "session-\(session.id)" }

    var body: some View {
        NavigationStack {
            Group {
                if session.endedAt != nil {
                    SessionSummaryView(session: session) { dismiss() }
                } else {
                    running
                }
            }
            .background(Palette.canvas.ignoresSafeArea())
        }
        .feedbackBanner($feedback)
        // A phone on a music stand shouldn't lock mid-session.
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            recorder.stop(ifOwnedBy: recordingOwner)
        }
    }

    private var running: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                SessionTimerHeader(session: session) { try? context.save() }
                StepStrip(session: session)
                stepContent
                    .id(session.currentStepIndex)
                stepNavigation
                VStack(alignment: .leading, spacing: 8) {
                    Text("Record").font(.headline)
                    RecordControl(owner: recordingOwner, title: "Session, \(session.startedAt.formatted(date: .abbreviated, time: .omitted))") { made in
                        made.session = session
                        made.task = session.focusTask
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    Label("Minimize", systemImage: "chevron.down")
                }
                .accessibilityHint("The session keeps running. Return from the bar at the bottom of the screen.")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Finish now", systemImage: "checkmark") { finish() }
                    Button("Discard session", systemImage: "trash", role: .destructive) { confirmingDiscard = true }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
            }
        }
        .confirmationDialog("Discard this session?", isPresented: $confirmingDiscard, titleVisibility: .visible) {
            Button("Discard session", role: .destructive) {
                recorder.stop(ifOwnedBy: recordingOwner)
                context.delete(session)
                try? context.save()
                dismiss()
            }
        } message: {
            Text("The session and its notes are deleted. Attempts and recordings you logged stay in the Journal.")
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        if let step = session.currentStep {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Label(step.kind.title, systemImage: step.kind.symbol)
                        .font(.displayTitle)
                        .foregroundStyle(Palette.ink)
                    Text("\(step.kind.prompt) About \(step.minutes) min.")
                        .foregroundStyle(Palette.inkSoft)
                }
                switch step.kind {
                case .focus:
                    FocusProblemPanel(session: session, feedback: $feedback)
                case .closing:
                    ClosingPanel(session: session)
                default:
                    TextField("Notes (optional)", text: Binding(
                        get: { session.note(for: step.kind) },
                        set: { session.setNote($0, for: step.kind) }
                    ), axis: .vertical)
                    .lineLimit(2...6)
                    .padding(14)
                    .background(Palette.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        } else {
            ClosingPanel(session: session)
        }
    }

    private var stepNavigation: some View {
        let steps = session.plan
        let isLast = session.currentStepIndex >= steps.count - 1
        return VStack(spacing: 10) {
            if isLast {
                Button("Finish session", action: finish).buttonStyle(.primary)
            } else {
                Button {
                    session.currentStepIndex += 1
                    try? context.save()
                } label: {
                    Text("Next: \(steps[session.currentStepIndex + 1].kind.title)")
                }
                .buttonStyle(.primary)
            }
        }
    }

    private func finish() {
        recorder.stop(ifOwnedBy: recordingOwner)
        session.finish()
        try? context.save()
    }
}

/// Big, calm timer with pause and resume.
private struct SessionTimerHeader: View {
    let session: PracticeSession
    var onChange: () -> Void
    @ScaledMetric(relativeTo: .largeTitle) private var timerSize: CGFloat = 60

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                VStack(alignment: .leading, spacing: 2) {
                    Text(SessionClock.format(session.elapsed(at: timeline.date)))
                        .font(.system(size: timerSize, weight: .light, design: .serif))
                        .monospacedDigit()
                        .foregroundStyle(session.isPaused ? Palette.inkSoft : Palette.ink)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text(session.isPaused ? "Paused" : "of \(session.plannedMinutes) min planned")
                        .font(.subheadline)
                        .foregroundStyle(Palette.inkSoft)
                }
                .accessibilityElement(children: .combine)
            }
            Spacer()
            Button {
                session.isPaused ? session.resume() : session.pause()
                onChange()
            } label: {
                Image(systemName: session.isPaused ? "play.fill" : "pause.fill")
                    .font(.title2)
                    .foregroundStyle(Palette.onForest)
                    .frame(width: 64, height: 64)
                    .background(Palette.forest, in: Circle())
            }
            .accessibilityLabel(session.isPaused ? "Resume" : "Pause")
        }
    }
}

/// The plan as a row of tappable steps. Any step can be skipped by tapping a
/// later one; nothing is marked as failed.
private struct StepStrip: View {
    @Bindable var session: PracticeSession

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(session.plan.enumerated()), id: \.offset) { index, step in
                    let isCurrent = index == session.currentStepIndex
                    Button {
                        session.currentStepIndex = index
                    } label: {
                        Label(step.kind.title, systemImage: step.kind.symbol)
                            .font(.subheadline.weight(isCurrent ? .semibold : .regular))
                            .foregroundStyle(isCurrent ? Palette.onForest : Palette.ink)
                            .padding(.horizontal, 12)
                            .frame(minHeight: 44)
                            .background(isCurrent ? Palette.forest : Palette.surfaceSunk, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isCurrent ? .isSelected : [])
                }
            }
        }
        .accessibilityLabel("Steps")
    }
}

private struct ClosingPanel: View {
    @Bindable var session: PracticeSession

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            LabeledField(title: "What's a little easier than when you started?",
                         placeholder: "Even one bar counts.", text: $session.closingEasier)
            LabeledField(title: "Next time, start with…",
                         placeholder: "The first thing to try.", text: $session.closingNext)
        }
    }
}

struct LabeledField: View {
    let title: String
    var placeholder: String = ""
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            TextField(placeholder, text: $text, axis: .vertical)
                .lineLimit(2...8)
                .padding(14)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Palette.hairline, lineWidth: 0.5))
        }
    }
}

/// End of session: what got easier (in your words, or experiments that
/// worked) and one natural next step.
struct SessionSummaryView: View {
    let session: PracticeSession
    var onDone: () -> Void

    private var worked: [Attempt] {
        session.attempts.filter { $0.outcome == .worked }.sorted { $0.date < $1.date }
    }

    private var nextLine: String? {
        if !session.closingNext.isBlank { return session.closingNext.trimmed }
        if let task = session.focusTask, let retest = task.pendingRetests.first {
            return "Cold retest of “\(task.title)” \(DayPhrase.until(retest.dueDate, now: .now))."
        }
        if let next = session.attempts.sorted(by: { $0.date > $1.date }).first(where: { !$0.nextStep.isBlank }) {
            return next.nextStep.trimmed
        }
        return nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Saved.")
                        .font(.display)
                    Text("\(session.practisedMinutesText) of practice, in the Journal now.")
                        .font(.title3)
                        .foregroundStyle(Palette.inkSoft)
                }

                if !session.closingEasier.isBlank || !worked.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("What got easier").font(.displayHeadline)
                        if !session.closingEasier.isBlank {
                            Text(session.closingEasier.trimmed)
                        }
                        ForEach(worked) { attempt in
                            Label {
                                Text([attempt.task?.title, attempt.tempo.map { "\($0) bpm" }].compactMap { $0 }.joined(separator: " at "))
                            } icon: {
                                Image(systemName: "checkmark").foregroundStyle(Palette.forest)
                            }
                        }
                    }
                    .surface()
                }

                if let nextLine {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Next").font(.displayHeadline)
                        Text(nextLine)
                    }
                    .surface()
                }

                Button("Done", action: onDone).buttonStyle(.primary)
            }
            .padding(24)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
    }
}

#if DEBUG
#Preview("Active session") {
    let container = PreviewData.container(.activeSession)
    let session = try! container.mainContext.fetch(FetchDescriptor<PracticeSession>()).first!
    return ActiveSessionView(session: session)
        .previewEnvironment(container: container)
}

#Preview("Paused session") {
    let container = PreviewData.container(.pausedSession)
    let session = try! container.mainContext.fetch(FetchDescriptor<PracticeSession>()).first!
    return ActiveSessionView(session: session)
        .previewEnvironment(container: container)
}
#endif
