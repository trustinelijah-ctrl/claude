import SwiftUI
import SwiftData
import PianoCore

/// Log one attempt: cold or after practice, with the user's own tempo,
/// diagnosis, observation, and next step. Also completes a cold retest.
struct LogAttemptView: View {
    let task: PracticeTask
    var session: PracticeSession? = nil
    var retest: Retest? = nil
    var onSaved: (ExperimentFeedback?) -> Void = { _ in }

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AudioRecorder.self) private var recorder

    @State private var phase: AttemptPhase
    @State private var tempoText = ""
    @State private var category: ErrorCategory?
    @State private var observation = ""
    @State private var smallerExercise: String
    @State private var outcome: ExperimentOutcome?
    @State private var nextStep = ""
    @State private var take = TakeHolder()

    private var recordingOwner: String { "attempt-\(task.id)" }

    init(task: PracticeTask, phase: AttemptPhase, session: PracticeSession? = nil, retest: Retest? = nil,
         smallerExercise: String = "", onSaved: @escaping (ExperimentFeedback?) -> Void = { _ in }) {
        self.task = task
        self.session = session
        self.retest = retest
        self.onSaved = onSaved
        _phase = State(initialValue: retest == nil ? phase : .cold)
        _smallerExercise = State(initialValue: smallerExercise)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(task.title).font(.headline)
                        if !task.contextSummary.isEmpty {
                            Text(task.contextSummary).font(.subheadline).foregroundStyle(Palette.inkSoft)
                        }
                    }
                    if let retest {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Set up \(DayPhrase.since(retest.scheduledAt, now: .now))")
                                .font(.subheadline.weight(.semibold))
                            if !retest.context.isEmpty {
                                Text(retest.context).font(.subheadline).foregroundStyle(Palette.inkSoft)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }

                Section {
                    Picker("Kind of attempt", selection: $phase) {
                        ForEach(AttemptPhase.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .disabled(retest != nil)
                } footer: {
                    Text(phase == .cold
                         ? "Cold means your first go at this today, with no warm-up on it."
                         : "After you've worked on it. Compared only with other after-practice attempts.")
                }

                Section("How it went") {
                    TempoField(text: $tempoText)
                    Picker("What got in the way", selection: $category) {
                        Text("Nothing in particular").tag(ErrorCategory?.none)
                        ForEach(ErrorCategory.allCases) { Text($0.label).tag(ErrorCategory?.some($0)) }
                    }
                    TextField("What happened? Be specific: which beat, which hand.", text: $observation, axis: .vertical)
                        .lineLimit(2...8)
                    if phase == .afterPractice {
                        TextField("The smaller exercise you used", text: $smallerExercise, axis: .vertical)
                    }
                }

                Section {
                    FlowLayout(spacing: 8) {
                        ForEach(ExperimentOutcome.allCases) { option in
                            Chip(title: option.label, isSelected: outcome == option) {
                                outcome = outcome == option ? nil : option
                            }
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text(retest == nil ? "Did the experiment work?" : "Did it hold up cold?")
                } footer: {
                    Text("Optional. Leave it blank if this wasn't a specific experiment.")
                }

                Section("Next step") {
                    TextField("One thing to try next time", text: $nextStep, axis: .vertical)
                }

                Section("Recording (optional)") {
                    RecordControl(owner: recordingOwner, title: "\(retest == nil ? phase.label : "Cold retest"): \(task.title)") { [take] made in
                        made.task = task
                        made.session = session
                        take.recording = made
                    }
                    if let recording = take.recording { RecordingRow(recording: recording) }
                }
            }
            .canvasBackground()
            .navigationTitle(retest == nil ? "Log attempt" : "Cold retest")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).fontWeight(.semibold) }
            }
        }
        // Cancelling mid-take still keeps the audio, linked to the task.
        .onDisappear { recorder.stop(ifOwnedBy: recordingOwner) }
    }

    private func save() {
        recorder.stop(ifOwnedBy: recordingOwner)
        let attempt = Attempt(task: task, phase: phase)
        attempt.tempo = TempoField.parse(tempoText)
        attempt.errorCategory = category
        attempt.observation = observation.trimmed
        attempt.smallerExercise = phase == .afterPractice ? smallerExercise.trimmed : ""
        attempt.outcome = outcome
        attempt.nextStep = nextStep.trimmed
        attempt.session = session
        context.insert(attempt)

        take.recording?.attempt = attempt
        if let retest {
            attempt.isRetest = true
            retest.completedAt = attempt.date
            retest.resultAttemptID = attempt.id
        }
        try? context.save()

        let feedback = outcome.map { ExperimentFeedback.after(outcome: $0, tempo: attempt.tempo, phase: phase) }
        onSaved(feedback)
        dismiss()
    }
}

/// Lets the user schedule a cold retest for a task, with context from its
/// latest attempt.
struct RetestPicker: View {
    let task: PracticeTask
    @Environment(\.modelContext) private var context

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let next = task.pendingRetests.first {
                Label("Cold retest \(DayPhrase.until(next.dueDate, now: .now))", systemImage: "snowflake")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.forest)
            }
            FlowLayout(spacing: 8) {
                ForEach(RetestInterval.allCases) { interval in
                    let scheduled = task.pendingRetests.contains {
                        Calendar.current.isDate($0.dueDate, inSameDayAs: interval.dueDate(from: .now))
                    }
                    Chip(title: interval.label, isSelected: scheduled) {
                        if !scheduled { schedule(interval) }
                    }
                }
            }
        }
    }

    private func schedule(_ interval: RetestInterval) {
        let retest = Retest(task: task, dueDate: interval.dueDate(from: .now), context: Retest.context(from: task.lastAttempt))
        context.insert(retest)
        try? context.save()
    }
}
