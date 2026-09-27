import SwiftUI
import SwiftData
import PianoCore

/// Everything about one target: its attempts (cold and after practice kept
/// apart), retests with their original context, recordings, and comparisons.
struct TaskDetailView: View {
    @Bindable var task: PracticeTask

    @Environment(AppState.self) private var app
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var logging: AttemptPhase?
    @State private var doingRetest: Retest?
    @State private var editing = false
    @State private var confirmingDelete = false
    @State private var feedback: ExperimentFeedback?

    private var comparisons: [BeforeNow] {
        EvidenceComparison.pairs(forTask: task.id, in: task.attempts.compactMap(\.evidencePoint))
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(task.title).font(.displayTitle)
                    if !task.contextSummary.isEmpty {
                        Text(task.contextSummary).foregroundStyle(Palette.inkSoft)
                    }
                    if let skill = task.skill {
                        Label(skill.name, systemImage: skill.branch.symbol)
                            .font(.subheadline)
                            .foregroundStyle(Palette.inkSoft)
                    }
                }
                .padding(.vertical, 6)

                Button("Practise this now") { app.planSession(focus: task) }
                    .buttonStyle(.primary)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                AdaptiveStack {
                    Button("Log cold pass") { logging = .cold }.buttonStyle(.secondary)
                    Button("Log after practice") { logging = .afterPractice }.buttonStyle(.secondary)
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 12, trailing: 16))
            }

            Section {
                ForEach(task.pendingRetests) { retest in
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Due \(DayPhrase.until(retest.dueDate, now: .now))", systemImage: "snowflake")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Palette.forest)
                        if !retest.context.isEmpty {
                            Text(retest.context).font(.subheadline)
                        }
                        Button("Do the retest now") { doingRetest = retest }
                            .font(.subheadline.weight(.semibold))
                            .buttonStyle(.borderless)
                            .frame(minHeight: 44)
                    }
                }
                .onDelete { offsets in
                    let pending = task.pendingRetests
                    offsets.map { pending[$0] }.forEach { context.delete($0) }
                    try? context.save()
                }
                RetestPicker(task: task)
                    .padding(.vertical, 4)
            } header: {
                Text("Cold retests")
            }

            if !comparisons.isEmpty {
                Section("Before and now") {
                    ForEach(comparisons, id: \.phase) { pair in
                        BeforeNowContent(pair: pair, taskTitle: nil, attempts: task.attempts)
                    }
                }
            }

            Section {
                if task.attempts.isEmpty {
                    Text("No attempts yet. A cold first pass is a good start: once through, before practising it.")
                        .foregroundStyle(Palette.inkSoft)
                }
                ForEach(task.sortedAttempts) { attempt in
                    NavigationLink { AttemptEditorView(attempt: attempt) } label: {
                        AttemptListRow(attempt: attempt)
                    }
                }
                .onDelete { offsets in
                    let sorted = task.sortedAttempts
                    offsets.map { sorted[$0] }.forEach { context.delete($0) }
                    try? context.save()
                }
            } header: {
                Text("Attempts")
            }

            let unattached = task.recordings.filter { $0.attempt == nil }.sorted { $0.createdAt > $1.createdAt }
            if !unattached.isEmpty {
                Section("Other recordings") {
                    ForEach(unattached) { RecordingRow(recording: $0) }
                        .onDelete { offsets in
                            offsets.map { unattached[$0] }.forEach { RecordingStore.delete($0, in: context) }
                            try? context.save()
                        }
                }
            }
        }
        .canvasBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Edit", systemImage: "pencil") { editing = true }
                    Button(task.isArchived ? "Unarchive" : "Archive", systemImage: "archivebox") {
                        task.isArchived.toggle()
                        try? context.save()
                    }
                    Button("Delete", systemImage: "trash", role: .destructive) { confirmingDelete = true }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
            }
        }
        .sheet(item: $logging) { phase in
            LogAttemptView(task: task, phase: phase) { feedback = $0 }
        }
        .sheet(item: $doingRetest) { retest in
            LogAttemptView(task: task, phase: .cold, retest: retest) { feedback = $0 }
        }
        .sheet(isPresented: $editing) { TaskEditorView(mode: .edit(task)) }
        .confirmationDialog("Delete “\(task.title)”?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete target and its attempts", role: .destructive) {
                context.delete(task)
                try? context.save()
                dismiss()
            }
        } message: {
            Text("Its attempts and retests are deleted. Recordings stay in the Journal.")
        }
        .feedbackBanner($feedback)
        .activeSessionBar()
    }
}

struct AttemptListRow: View {
    let attempt: Attempt

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                PhaseBadge(attempt: attempt)
                Spacer()
                Text(attempt.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(Palette.inkSoft)
            }
            HStack(spacing: 8) {
                if let tempo = attempt.tempo { Text("\(tempo) bpm").monospacedDigit() }
                if let category = attempt.errorCategory { Text(category.label) }
                if let outcome = attempt.outcome { Text(outcome.label) }
                if attempt.recording != nil { Image(systemName: "waveform").accessibilityLabel("Has recording") }
            }
            .font(.subheadline.weight(.medium))
            if !attempt.observation.isBlank { Text(attempt.observation).lineLimit(3) }
            if !attempt.nextStep.isBlank {
                Text("Next: \(attempt.nextStep)").font(.subheadline).foregroundStyle(Palette.inkSoft)
            }
        }
        .padding(.vertical, 4)
    }
}

/// Edit an attempt after the fact. Changing it never touches other entries.
struct AttemptEditorView: View {
    @Bindable var attempt: Attempt
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var tempoText = ""
    @State private var confirmingDelete = false

    var body: some View {
        Form {
            Section {
                Picker("Kind of attempt", selection: Binding(get: { attempt.phase }, set: { attempt.phase = $0 })) {
                    ForEach(AttemptPhase.allCases) { Text($0.label).tag($0) }
                }
                .disabled(attempt.isRetest)
                DatePicker("When", selection: $attempt.date)
            }
            Section("How it went") {
                TempoField(text: $tempoText)
                    .onChange(of: tempoText) { _, new in attempt.tempo = TempoField.parse(new) }
                Picker("What got in the way", selection: Binding(get: { attempt.errorCategory }, set: { attempt.errorCategory = $0 })) {
                    Text("Nothing in particular").tag(ErrorCategory?.none)
                    ForEach(ErrorCategory.allCases) { Text($0.label).tag(ErrorCategory?.some($0)) }
                }
                Picker("Outcome", selection: Binding(get: { attempt.outcome }, set: { attempt.outcome = $0 })) {
                    Text("Not an experiment").tag(ExperimentOutcome?.none)
                    ForEach(ExperimentOutcome.allCases) { Text($0.label).tag(ExperimentOutcome?.some($0)) }
                }
                TextField("What happened", text: $attempt.observation, axis: .vertical)
                if attempt.phase == .afterPractice {
                    TextField("Smaller exercise", text: $attempt.smallerExercise, axis: .vertical)
                }
                TextField("Next step", text: $attempt.nextStep, axis: .vertical)
            }
            if !attempt.recordings.isEmpty {
                Section("Recordings") {
                    ForEach(attempt.recordings) { RecordingRow(recording: $0) }
                        .onDelete { offsets in
                            let items = attempt.recordings
                            offsets.map { items[$0] }.forEach { RecordingStore.delete($0, in: context) }
                            try? context.save()
                        }
                }
            }
            Section {
                Button("Delete attempt", role: .destructive) { confirmingDelete = true }
            }
        }
        .canvasBackground()
        .navigationTitle("Attempt")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { tempoText = attempt.tempo.map(String.init) ?? "" }
        .onDisappear { try? context.save() }
        .confirmationDialog("Delete this attempt?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete attempt", role: .destructive) {
                context.delete(attempt)
                try? context.save()
                dismiss()
            }
        } message: {
            Text("Only this attempt is deleted. Its recording stays in the Journal.")
        }
    }
}

/// Create or edit a target.
struct TaskEditorView: View {
    enum Mode: Identifiable {
        case new(skill: Skill?, piece: Piece?)
        case edit(PracticeTask)

        var id: String {
            switch self {
            case .new(let skill, let piece): "new-\(skill?.id.uuidString ?? "")-\(piece?.id.uuidString ?? "")"
            case .edit(let task): "edit-\(task.id)"
            }
        }
    }

    let mode: Mode
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Skill.name) private var skills: [Skill]
    @Query(sort: \Piece.title) private var pieces: [Piece]

    @State private var title = ""
    @State private var contextNote = ""
    @State private var skillID: UUID?
    @State private var pieceID: UUID?
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Target, e.g. Bars 9–12 hands together at 60", text: $title, axis: .vertical)
                    TextField("Context: edition, fingering, which hand", text: $contextNote, axis: .vertical)
                } footer: {
                    Text("Make it observable: something you could check next week and get the same answer.")
                }
                Section {
                    Picker("Skill", selection: $skillID) {
                        Text("None").tag(UUID?.none)
                        ForEach(SkillBranch.allCases) { branch in
                            let branchSkills = skills.filter { $0.branch == branch }
                            if !branchSkills.isEmpty {
                                Section(branch.title) {
                                    ForEach(branchSkills) { Text($0.name).tag(UUID?.some($0.id)) }
                                }
                            }
                        }
                    }
                    Picker("Piece", selection: $pieceID) {
                        Text("None").tag(UUID?.none)
                        ForEach(pieces) { Text($0.title).tag(UUID?.some($0.id)) }
                    }
                }
            }
            .canvasBackground()
            .navigationTitle(isNew ? "New target" : "Edit target")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(title.isBlank)
                }
            }
            .onAppear(perform: load)
        }
    }

    private var isNew: Bool {
        if case .new = mode { return true }
        return false
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        switch mode {
        case .new(let skill, let piece):
            skillID = skill?.id
            pieceID = piece?.id
        case .edit(let task):
            title = task.title
            contextNote = task.contextNote
            skillID = task.skill?.id
            pieceID = task.piece?.id
        }
    }

    private func save() {
        let task: PracticeTask
        switch mode {
        case .new:
            task = PracticeTask(title: title.trimmed)
            context.insert(task)
        case .edit(let existing):
            task = existing
            task.title = title.trimmed
        }
        task.contextNote = contextNote.trimmed
        task.skill = skills.first { $0.id == skillID }
        task.piece = pieces.first { $0.id == pieceID }
        try? context.save()
        dismiss()
    }
}

#if DEBUG
#Preview("Task with evidence") {
    let container = PreviewData.container(.severalWeeks)
    let task = try! container.mainContext.fetch(FetchDescriptor<PracticeTask>()).first { $0.attempts.count > 2 }!
    return NavigationStack { TaskDetailView(task: task) }
        .previewEnvironment(container: container)
}
#endif
