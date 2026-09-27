import SwiftUI
import SwiftData
import PianoCore

/// One focused problem, in order: target, cold try, diagnosis, a smaller
/// exercise, the correction, a variation, back into the music, and a retest.
/// Any part can be left blank.
struct FocusProblemPanel: View {
    @Bindable var session: PracticeSession
    @Binding var feedback: ExperimentFeedback?

    @Environment(\.modelContext) private var context
    @Query(sort: \PracticeTask.createdAt, order: .reverse) private var tasks: [PracticeTask]
    @State private var newTarget = ""
    @State private var logging: AttemptPhase?

    private var coldAttempt: Attempt? {
        session.attempts.filter { $0.phase == .cold && $0.task?.id == session.focusTask?.id }.min { $0.date < $1.date }
    }

    private var practisedAttempts: [Attempt] {
        session.attempts.filter { $0.phase == .afterPractice && $0.task?.id == session.focusTask?.id }.sorted { $0.date < $1.date }
    }

    var body: some View {
        if let task = session.focusTask {
            VStack(alignment: .leading, spacing: 24) {
                target(task)
                coldTry(task)
                diagnosis
                LabeledField(title: "Make it smaller",
                             placeholder: coldAttempt?.errorCategory?.shrinkIdea ?? "Fewer notes, one hand, slower, or just the join.",
                             text: $session.focusSmallerExercise)
                LabeledField(title: "What fixed it",
                             placeholder: "The fingering, the count, the movement that made it work.",
                             text: $session.focusCorrection)
                LabeledField(title: "Vary it",
                             placeholder: "Change one thing: rhythm, tempo, dynamics, hands, register.",
                             text: $session.focusVariation)
                backIntoMusic(task)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Test it later, cold").font(.headline)
                    Text("Today's version is the warmed-up one. A retest shows whether it stuck.")
                        .font(.subheadline)
                        .foregroundStyle(Palette.inkSoft)
                    RetestPicker(task: task)
                }
            }
            .sheet(item: $logging) { phase in
                LogAttemptView(task: task, phase: phase, session: session,
                               smallerExercise: session.focusSmallerExercise) { result in
                    feedback = result
                }
            }
        } else {
            chooseTarget
        }
    }

    private func target(_ task: PracticeTask) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(task.title).font(.displayHeadline)
            if !task.contextSummary.isEmpty {
                Text(task.contextSummary).foregroundStyle(Palette.inkSoft)
            }
        }
        .surface()
    }

    @ViewBuilder
    private func coldTry(_ task: PracticeTask) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Try it cold").font(.headline)
            if let cold = coldAttempt {
                AttemptSummary(attempt: cold)
            } else {
                Text("Once through, before any practice on it. Note what happened.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.inkSoft)
                Button("Log cold first pass") { logging = .cold }
                    .buttonStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var diagnosis: some View {
        if let category = coldAttempt?.errorCategory {
            VStack(alignment: .leading, spacing: 6) {
                Text("What got in the way").font(.headline)
                Text(category.label)
                Text(category.shrinkIdea)
                    .font(.subheadline)
                    .foregroundStyle(Palette.inkSoft)
            }
        }
    }

    private func backIntoMusic(_ task: PracticeTask) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            LabeledField(title: "Back into the music",
                         placeholder: "Play it with the bars around it. What happened?",
                         text: $session.focusReintegration)
            ForEach(practisedAttempts) { AttemptSummary(attempt: $0) }
            Button(practisedAttempts.isEmpty ? "Log attempt after practice" : "Log another attempt") { logging = .afterPractice }
                .buttonStyle(.secondary)
        }
    }

    private var chooseTarget: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Pick one thing that doesn't work yet. Make it something you could check: a passage, a hand, a tempo.")
                .foregroundStyle(Palette.inkSoft)
            TextField("e.g. Bars 9–12, hands together, no stops", text: $newTarget, axis: .vertical)
                .padding(14)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Palette.hairline, lineWidth: 0.5))
            Button("Set target") {
                let task = PracticeTask(title: newTarget.trimmed)
                context.insert(task)
                session.focusTask = task
                try? context.save()
            }
            .buttonStyle(.secondary)
            .disabled(newTarget.isBlank)

            let existing = tasks.filter { !$0.isArchived }.prefix(12)
            if !existing.isEmpty {
                Menu {
                    ForEach(existing) { task in
                        Button(task.title) {
                            session.focusTask = task
                            try? context.save()
                        }
                    }
                } label: {
                    Label("Choose an existing target", systemImage: "list.bullet")
                        .frame(minHeight: 44)
                }
            }
        }
    }
}

/// Compact read-only view of one attempt.
struct AttemptSummary: View {
    let attempt: Attempt

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                PhaseBadge(attempt: attempt)
                if let tempo = attempt.tempo {
                    Text("\(tempo) bpm").font(.subheadline.monospacedDigit()).foregroundStyle(Palette.inkSoft)
                }
                if let outcome = attempt.outcome {
                    Text(outcome.label).font(.subheadline.weight(.medium)).foregroundStyle(Palette.inkSoft)
                }
            }
            if let category = attempt.errorCategory {
                Text(category.label).font(.subheadline.weight(.medium))
            }
            if !attempt.observation.isBlank { Text(attempt.observation) }
            if !attempt.nextStep.isBlank {
                Text("Next: \(attempt.nextStep)").font(.subheadline).foregroundStyle(Palette.inkSoft)
            }
            if let recording = attempt.recording {
                PlayButton(recording: recording)
            }
        }
        .surface(padding: 14)
    }
}
