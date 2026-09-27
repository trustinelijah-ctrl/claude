import SwiftUI
import SwiftData
import PianoCore

enum SuggestionProvider {
    static func current(tasks: [PracticeTask], retests: [Retest], skills: [Skill], now: Date = .now) -> Suggestion? {
        SuggestionEngine.suggest(
            tasks: tasks.map(\.snapshot),
            retests: retests.compactMap(\.snapshot),
            bottleneckSkillName: skills.first(where: \.isBottleneck)?.name,
            now: now
        )
    }
}

extension AppState {
    /// One live session at a time: if something is already running, return to it.
    func startJustPlay(in context: ModelContext) {
        let running = FetchDescriptor<PracticeSession>(predicate: #Predicate<PracticeSession> { $0.endedAt == nil })
        if let existing = try? context.fetch(running).first {
            open(existing)
            return
        }
        let session = PracticeSession(kind: .justPlay)
        context.insert(session)
        try? context.save()
        cover = .justPlay(session)
    }
}

/// Choose a length, a focus, and adjust the plan. Opens with the last length
/// you used and today's suggestion already selected, so it's one tap to begin.
struct SessionSetupView: View {
    let preselectedTaskID: UUID?

    private enum Focus: Hashable {
        case later
        case task(UUID)
        case new
    }

    @Environment(AppState.self) private var app
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \PracticeTask.createdAt, order: .reverse) private var tasks: [PracticeTask]
    @Query private var retests: [Retest]
    @Query private var skills: [Skill]
    @Query(filter: #Predicate<PracticeSession> { $0.endedAt == nil }) private var running: [PracticeSession]

    @AppStorage("lastSessionMinutes") private var lastMinutes = 30

    @State private var minutes = 30
    @State private var isCustom = false
    @State private var plan: [PlannedStep] = SessionPlanner.template(minutes: 30)
    @State private var focus: Focus = .later
    @State private var newTarget = ""
    @State private var didLoad = false

    private var activeTasks: [PracticeTask] { tasks.filter { !$0.isArchived } }
    private var totalMinutes: Int { plan.reduce(0) { $0 + $1.minutes } }

    var body: some View {
        let suggestion = SuggestionProvider.current(tasks: tasks, retests: retests, skills: skills)
        return NavigationStack {
            Form {
                if let session = running.first {
                    Section {
                        Text(session.kind == .justPlay ? "You're in Just play." : "A session is already running.")
                        Button("Return to it") {
                            app.pendingCover = session.kind == .justPlay ? .justPlay(session) : .session(session)
                            dismiss()
                        }
                    }
                } else {
                    lengthSection
                    focusSection(suggestion)
                    planSection
                    Section {
                        Button(action: begin) {
                            Text("Begin · \(totalMinutes) min")
                        }
                        .buttonStyle(.primary)
                        .disabled(plan.isEmpty || (focus == .new && newTarget.isBlank))
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }
                }
            }
            .canvasBackground()
            .navigationTitle("Plan a session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .onAppear { loadDefaults(suggestion) }
        }
    }

    private var lengthSection: some View {
        Section {
            FlowLayout(spacing: 8) {
                ForEach(SessionPlanner.presetMinutes, id: \.self) { preset in
                    Chip(title: "\(preset) min", isSelected: !isCustom && minutes == preset) {
                        isCustom = false
                        setMinutes(preset)
                    }
                }
                Chip(title: "Custom", isSelected: isCustom) {
                    isCustom = true
                }
            }
            .padding(.vertical, 4)
            if isCustom {
                Stepper(value: Binding(get: { minutes }, set: { setMinutes($0) }),
                        in: SessionPlanner.minimumMinutes...SessionPlanner.maximumMinutes, step: 5) {
                    Text("\(minutes) minutes")
                }
            }
        } header: {
            Text("How long")
        }
    }

    /// The suggested task, then whatever is selected (so an older target
    /// opened from its own page still shows as chosen), then recent ones.
    private func focusOptions(_ suggestion: Suggestion?) -> [PracticeTask] {
        var ids: [UUID] = []
        if let id = suggestion?.taskID { ids.append(id) }
        if case .task(let id) = focus, !ids.contains(id) { ids.append(id) }
        let pinned = ids.compactMap { id in tasks.first { $0.id == id } }
        let recent = activeTasks.filter { !ids.contains($0.id) }.prefix(8)
        return pinned + recent
    }

    private func focusSection(_ suggestion: Suggestion?) -> some View {
        Section {
            Picker("Focus", selection: $focus) {
                ForEach(focusOptions(suggestion)) { task in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(task.title)
                        if task.id == suggestion?.taskID, let reason = suggestion?.reason {
                            Text(reason).font(.footnote).foregroundStyle(Palette.inkSoft)
                        }
                    }
                    .tag(Focus.task(task.id))
                }
                Text("Something new…").tag(Focus.new)
                Text("Decide during the session").tag(Focus.later)
            }
            .pickerStyle(.inline)
            .labelsHidden()

            if focus == .new {
                TextField("Something you could check, like “bars 9–12, hands together, no stops”", text: $newTarget, axis: .vertical)
            }
        } header: {
            Text("One focused problem")
        }
    }

    private var planSection: some View {
        Section {
            ForEach($plan) { $step in
                Stepper(value: $step.minutes, in: 1...120) {
                    HStack {
                        Label(step.kind.title, systemImage: step.kind.symbol)
                        Spacer()
                        Text("\(step.minutes) min").monospacedDigit().foregroundStyle(Palette.inkSoft)
                    }
                }
                .accessibilityValue("\(step.minutes) minutes")
            }
            .onDelete { plan.remove(atOffsets: $0) }
        } header: {
            Text("Plan")
        } footer: {
            Text("A starting shape to change, not a rule. Adjust the minutes, or swipe left to drop a step.")
        }
    }

    private func setMinutes(_ value: Int) {
        minutes = value
        plan = SessionPlanner.template(minutes: value)
    }

    private func loadDefaults(_ suggestion: Suggestion?) {
        guard !didLoad else { return }
        didLoad = true
        isCustom = !SessionPlanner.presetMinutes.contains(lastMinutes)
        setMinutes(lastMinutes)
        // An explicitly chosen task wins even if archived; a suggestion only
        // ever names an active one.
        if let id = preselectedTaskID ?? suggestion?.taskID, tasks.contains(where: { $0.id == id }) {
            focus = .task(id)
        }
    }

    private func begin() {
        var task: PracticeTask?
        switch focus {
        case .later: task = nil
        case .task(let id): task = tasks.first { $0.id == id }
        case .new:
            let created = PracticeTask(title: newTarget.trimmed)
            context.insert(created)
            task = created
        }
        let session = PracticeSession(kind: .practice, plan: plan, focusTask: task)
        context.insert(session)
        try? context.save()
        lastMinutes = minutes
        app.pendingCover = .session(session)
        dismiss()
    }
}

#if DEBUG
#Preview("Setup") {
    SessionSetupView(preselectedTaskID: nil)
        .previewEnvironment(.severalWeeks)
}
#endif
