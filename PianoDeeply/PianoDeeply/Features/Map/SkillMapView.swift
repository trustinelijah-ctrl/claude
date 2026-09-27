import SwiftUI
import SwiftData
import PianoCore

/// The skill landscape: eight branches, each with editable subskills in
/// qualitative states. No totals, no percentages.
struct SkillMapView: View {
    @Environment(AppState.self) private var app
    @Query(sort: \Skill.sortOrder) private var skills: [Skill]

    private var bottleneck: Skill? { skills.first(where: \.isBottleneck) }
    private var nothingExplored: Bool { skills.allSatisfy { $0.state == .notExplored } }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if let bottleneck {
                        BottleneckSummary(skill: bottleneck)
                    } else {
                        Text(nothingExplored
                             ? "Everything starts as Not explored and only changes when you change it. Open a branch, set where you are, and mark the one skill that's holding you back."
                             : "No bottleneck marked. Open a skill and mark the one that's getting in the way most; Today will suggest work on it.")
                            .foregroundStyle(Palette.inkSoft)
                            .padding(.vertical, 4)
                    }
                }

                Section("Branches") {
                    ForEach(SkillBranch.allCases) { branch in
                        NavigationLink { BranchView(branch: branch) } label: {
                            BranchRow(branch: branch, skills: skills.filter { $0.branch == branch })
                        }
                    }
                }

                Section {
                    NavigationLink { ChordExplorerView() } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("ii–V–I in F", systemImage: "pianokeys")
                                .font(.body.weight(.medium))
                            KeyboardView(range: 53...77,
                                         marks: [55: .bass, 58: .tone, 62: .tone, 65: .tone])
                                .frame(height: 54)
                                .accessibilityHidden(true)
                        }
                        .padding(.vertical, 6)
                    }
                } header: {
                    Text("On the keyboard")
                } footer: {
                    Text("See each chord's notes, step through its inversions, and try the smooth voice leading.")
                }
            }
            .canvasBackground()
            .navigationTitle("Map")
            .activeSessionBar()
        }
    }
}

private struct BranchRow: View {
    let branch: SkillBranch
    let skills: [Skill]

    private var explored: [Skill] { skills.filter { $0.state != .notExplored } }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: branch.symbol)
                .font(.title3)
                .foregroundStyle(Palette.forest)
                .frame(width: 30)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(branch.title).font(.body.weight(.semibold))
                    if skills.contains(where: \.isBottleneck) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(Palette.brass)
                            .accessibilityLabel("Contains your bottleneck")
                    }
                }
                Text(branch.summary)
                    .font(.subheadline)
                    .foregroundStyle(Palette.inkSoft)
                if !explored.isEmpty {
                    FlowLayout(spacing: 6) {
                        ForEach(explored) { skill in
                            StateTag(state: skill.state, text: skill.name)
                        }
                    }
                    .padding(.top, 2)
                }
            }
        }
        .padding(.vertical, 6)
    }
}

/// A subskill name tinted by its state: darker and more forest as it moves
/// from understood towards usable freely. Always labelled in words too.
struct StateTag: View {
    let state: SkillState
    var text: String? = nil

    var body: some View {
        Text(text ?? state.label)
            .font(.caption.weight(.semibold))
            .foregroundStyle(state.rank >= 3 ? Palette.onForest : Palette.forest)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(state.rank >= 3 ? Palette.forest : Palette.forestWash, in: Capsule())
            .accessibilityLabel(text.map { "\($0), \(state.label)" } ?? state.label)
    }
}

extension SkillState {
    var rank: Int { SkillState.allCases.firstIndex(of: self) ?? 0 }
}

private struct BottleneckSummary: View {
    let skill: Skill
    @Environment(AppState.self) private var app

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                Text(skill.name).font(.displayHeadline)
            } icon: {
                Image(systemName: "exclamationmark.circle.fill").foregroundStyle(Palette.brass)
            }
            .accessibilityLabel("Current bottleneck: \(skill.name)")
            Text("Your current bottleneck, in \(skill.branch.title.lowercased()).")
                .font(.subheadline.weight(.medium))
            if let last = skill.lastAttempt, let task = last.task {
                Text("Last time: \(task.title), \(DayPhrase.since(last.date, now: .now)). \(last.phaseLabel)\(last.observation.isBlank ? "." : ": \(last.observation)")")
                    .font(.subheadline)
                    .foregroundStyle(Palette.inkSoft)
                Button("Practise it") { app.planSession(focus: task) }
                    .buttonStyle(.secondary)
            } else {
                Text("Nothing logged for it yet. Add a target where it shows up.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.inkSoft)
                NavigationLink("Open skill") { SkillDetailView(skill: skill) }
            }
        }
        .padding(.vertical, 6)
    }
}

struct BranchView: View {
    let branch: SkillBranch
    @Environment(\.modelContext) private var context
    @Query(sort: \Skill.sortOrder) private var allSkills: [Skill]
    @State private var addingName = ""
    @State private var showingAdd = false

    private var skills: [Skill] { allSkills.filter { $0.branch == branch } }

    var body: some View {
        List {
            Section {
                Text(branch.summary).foregroundStyle(Palette.inkSoft)
            }
            Section {
                if skills.isEmpty {
                    Text("No subskills here. Add the ones that matter to you.")
                        .foregroundStyle(Palette.inkSoft)
                }
                ForEach(skills) { skill in
                    NavigationLink { SkillDetailView(skill: skill) } label: { SkillRow(skill: skill) }
                        .swipeActions(edge: .leading) {
                            Button(skill.isBottleneck ? "Clear" : "Bottleneck") {
                                SkillSeeder.markBottleneck(skill, in: allSkills)
                                try? context.save()
                            }
                            .tint(Palette.brass)
                        }
                        // Rows with custom swipe actions lose the automatic
                        // delete, so it's spelled out here.
                        .swipeActions(edge: .trailing) {
                            Button("Delete", role: .destructive) {
                                context.delete(skill)
                                try? context.save()
                            }
                        }
                }
                Button { showingAdd = true } label: { Label("Add subskill", systemImage: "plus") }
            } header: {
                Text("Subskills")
            } footer: {
                Text("Swipe right to mark a bottleneck, left to delete.")
            }
        }
        .canvasBackground()
        .navigationTitle(branch.title)
        .alert("Add subskill", isPresented: $showingAdd) {
            TextField("Name", text: $addingName)
            Button("Add") {
                guard !addingName.isBlank else { return }
                let skill = Skill(branch: branch, name: addingName.trimmed, evidence: "", sortOrder: (skills.map(\.sortOrder).max() ?? -1) + 1)
                context.insert(skill)
                try? context.save()
                addingName = ""
            }
            Button("Cancel", role: .cancel) { addingName = "" }
        }
        .activeSessionBar()
    }
}

private struct SkillRow: View {
    let skill: Skill

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(skill.name).font(.body.weight(.medium))
                if skill.isBottleneck {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(Palette.brass)
                        .accessibilityLabel("Bottleneck")
                }
            }
            StateTag(state: skill.state)
            if let last = skill.lastAttempt {
                Text("Last worked on \(DayPhrase.since(last.date, now: .now))")
                    .font(.subheadline)
                    .foregroundStyle(Palette.inkSoft)
            }
        }
        .padding(.vertical, 4)
    }
}

struct SkillDetailView: View {
    @Bindable var skill: Skill
    @Environment(\.modelContext) private var context
    @Query private var allSkills: [Skill]
    @State private var addingTask = false

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $skill.name)
                TextField("What would count as evidence?", text: $skill.evidence, axis: .vertical)
            } footer: {
                Text("Evidence is something you could check: a tempo, a recording, doing it cold.")
            }

            Section("Where you are") {
                Picker("State", selection: Binding(get: { skill.state }, set: { skill.state = $0 })) {
                    ForEach(SkillState.allCases) { state in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(state.label)
                            Text(state.meaning).font(.footnote).foregroundStyle(Palette.inkSoft)
                        }
                        .tag(state)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }

            Section {
                Toggle("Current bottleneck", isOn: Binding(
                    get: { skill.isBottleneck },
                    set: { _ in SkillSeeder.markBottleneck(skill, in: allSkills) }
                ))
            } footer: {
                Text("One at a time. Today's suggestion will tell you when it's based on this.")
            }

            Section {
                ForEach(skill.tasks.sorted { $0.createdAt > $1.createdAt }) { task in
                    NavigationLink { TaskDetailView(task: task) } label: { TaskRow(task: task) }
                }
                Button { addingTask = true } label: { Label("New target for this skill", systemImage: "plus") }
            } header: {
                Text("Targets")
            }
        }
        .canvasBackground()
        .navigationTitle(skill.name)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { try? context.save() }
        .sheet(isPresented: $addingTask) { TaskEditorView(mode: .new(skill: skill, piece: nil)) }
    }
}

#if DEBUG
#Preview("Map, fresh") {
    SkillMapView()
        .previewEnvironment(.fresh)
}

#Preview("Map, several weeks") {
    SkillMapView()
        .previewEnvironment(.severalWeeks)
}
#endif
