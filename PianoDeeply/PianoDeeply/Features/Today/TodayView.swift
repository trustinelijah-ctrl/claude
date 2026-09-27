import SwiftUI
import SwiftData
import PianoCore

/// "What can I play today?" One clear start, one suggestion with its reason,
/// and quiet context underneath.
struct TodayView: View {
    @Environment(AppState.self) private var app
    @Environment(\.modelContext) private var context

    @Query(sort: \PracticeTask.createdAt, order: .reverse) private var tasks: [PracticeTask]
    @Query private var retests: [Retest]
    @Query private var skills: [Skill]
    @Query(filter: #Predicate<Piece> { $0.isCurrent == true }, sort: \Piece.createdAt, order: .reverse) private var currentPieces: [Piece]
    @Query(sort: \PracticeSession.startedAt, order: .reverse) private var sessions: [PracticeSession]
    @Query(TodayView.latestAttempt) private var latestAttempts: [Attempt]
    @AppStorage("inventoryHidden") private var inventoryHidden = false
    @AppStorage("lastSessionMinutes") private var lastMinutes = 30

    @State private var doingRetest: Retest?
    @State private var addingTargetFor: Skill?
    @State private var feedback: ExperimentFeedback?

    private static var latestAttempt: FetchDescriptor<Attempt> {
        var descriptor = FetchDescriptor<Attempt>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = 1
        return descriptor
    }

    private var running: PracticeSession? { sessions.first { $0.endedAt == nil } }
    private var suggestion: Suggestion? { SuggestionProvider.current(tasks: tasks, retests: retests, skills: skills) }
    private var inventoryDone: Int { Inventory.doneCount(in: tasks) }

    private var lastPlayed: Date? {
        [sessions.first(where: { $0.endedAt != nil })?.startedAt, latestAttempts.first?.date].compactMap { $0 }.max()
    }

    private var isReturning: Bool {
        ReturnGreeting.isLongGap(lastPlayed: lastPlayed, now: .now)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    header
                    startBlock
                    if let suggestion { suggestionBlock(suggestion) }
                    if inventoryDone < InventorySample.allCases.count && !inventoryHidden { inventoryBlock }
                    piecesBlock
                    if !isReturning && running == nil { justPlayRow }
                    retestPreview
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
            }
            .background(Palette.canvas.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { app.sheet = .settings } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
            }
            .activeSessionBar()
            .feedbackBanner($feedback)
            .sheet(item: $doingRetest) { retest in
                if let task = retest.task {
                    LogAttemptView(task: task, phase: .cold, retest: retest) { feedback = $0 }
                }
            }
            .sheet(item: $addingTargetFor) { skill in
                TaskEditorView(mode: .new(skill: skill, piece: nil))
            }
        }
    }

    // MARK: Blocks

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            KeyboardMotif()
            Text(ReturnGreeting.headline(lastPlayed: lastPlayed, now: .now))
                .font(.display)
                .foregroundStyle(Palette.ink)
            Text(isReturning
                 ? "Good to see you. Start with something you like playing."
                 : Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .font(.title3)
                .foregroundStyle(Palette.inkSoft)
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private var startBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let running {
                Button { app.open(running) } label: {
                    TimelineView(.periodic(from: .now, by: 1)) { timeline in
                        Text("Return to session · \(SessionClock.format(running.elapsed(at: timeline.date)))")
                            .monospacedDigit()
                    }
                }
                .buttonStyle(.primary)
            } else if isReturning {
                Button("Just play") { app.startJustPlay(in: context) }
                    .buttonStyle(.primary)
                Button("Start practice") { app.planSession() }
                    .buttonStyle(.secondary)
            } else {
                Button("Start practice") { app.planSession() }
                    .buttonStyle(.primary)
                Text(startCaption)
                    .font(.subheadline)
                    .foregroundStyle(Palette.inkSoft)
            }
        }
    }

    private var startCaption: String {
        var parts = ["\(lastMinutes) min"]
        if let id = suggestion?.taskID, let task = tasks.first(where: { $0.id == id }) {
            parts.append("focus: \(task.title)")
        }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private func suggestionBlock(_ suggestion: Suggestion) -> some View {
        let task = suggestion.taskID.flatMap { id in tasks.first { $0.id == id } }
        VStack(alignment: .leading, spacing: 12) {
            Text(suggestion.title)
                .font(.displayHeadline)
                .foregroundStyle(Palette.ink)
            Label {
                Text(suggestion.reason)
            } icon: {
                Image(systemName: suggestion.rule == .retestDue ? "snowflake" : "lightbulb")
                    .foregroundStyle(Palette.brass)
            }
            .font(.subheadline)
            .foregroundStyle(Palette.inkSoft)

            AdaptiveStack {
                switch suggestion.rule {
                case .retestDue:
                    Button("Do the retest") {
                        doingRetest = retests.first { $0.id == suggestion.retestID }
                    }
                    .buttonStyle(.secondary)
                case .bottleneckNeedsTask:
                    Button("Add a target for it") {
                        addingTargetFor = skills.first(where: \.isBottleneck)
                    }
                    .buttonStyle(.secondary)
                default:
                    Button("Practise this") { app.planSession(focus: task) }
                        .buttonStyle(.secondary)
                }
                if let task {
                    NavigationLink { TaskDetailView(task: task) } label: {
                        Text("Open")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                }
            }
        }
        .surface()
    }

    private var inventoryBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Six-sample inventory")
                .font(.displayHeadline)
            Text(inventoryDone == 0
                 ? "Six short things played cold, about fifteen minutes. A starting point to compare against in four weeks."
                 : "\(inventoryDone) of 6 logged. The rest can wait until you feel like it.")
                .foregroundStyle(Palette.inkSoft)
            AdaptiveStack {
                Button(inventoryDone == 0 ? "Start" : "Continue") { app.sheet = .inventory }
                    .buttonStyle(.secondary)
                Button("Hide") { inventoryHidden = true }
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
        }
        .surface()
    }

    @ViewBuilder
    private var piecesBlock: some View {
        if let piece = currentPieces.first {
            NavigationLink { PieceDetailView(piece: piece) } label: {
                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: "music.quarternote.3")
                        .font(.title2)
                        .foregroundStyle(Palette.forest)
                        .frame(width: 32)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(piece.title).font(.headline).foregroundStyle(Palette.ink)
                        Text(pieceCaption(piece))
                            .font(.subheadline)
                            .foregroundStyle(Palette.inkSoft)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(Palette.inkSoft).accessibilityHidden(true)
                }
                .surface(padding: 16)
            }
            .buttonStyle(.plain)
        }
    }

    private func pieceCaption(_ piece: Piece) -> String {
        var parts: [String] = []
        if !piece.composer.isEmpty { parts.append(piece.composer) }
        if let last = piece.lastWorkedOn {
            parts.append("last worked on \(DayPhrase.since(last, now: .now))")
        }
        if currentPieces.count > 1 { parts.append("+\(currentPieces.count - 1) more current") }
        return parts.isEmpty ? "No targets yet" : parts.joined(separator: " · ")
    }

    private var justPlayRow: some View {
        Button { app.startJustPlay(in: context) } label: {
            HStack(spacing: 14) {
                Image(systemName: "music.note")
                    .font(.title2)
                    .foregroundStyle(Palette.forest)
                    .frame(width: 32)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Just play").font(.headline).foregroundStyle(Palette.ink)
                    Text("No goals. A timer and recording only if you want them.")
                        .font(.subheadline)
                        .foregroundStyle(Palette.inkSoft)
                }
                Spacer()
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var retestPreview: some View {
        if let next = SuggestionEngine.nextUpcomingRetest(retests.compactMap(\.snapshot), now: .now),
           let task = tasks.first(where: { $0.id == next.taskID }) {
            NavigationLink { TaskDetailView(task: task) } label: {
                Label {
                    Text("Next cold retest: \(task.title), \(DayPhrase.until(next.dueDate, now: .now))")
                } icon: {
                    Image(systemName: "snowflake")
                }
                .font(.subheadline)
                .foregroundStyle(Palette.inkSoft)
                .frame(minHeight: 44, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
    }
}

#if DEBUG
#Preview("Fresh install") {
    TodayView()
        .previewEnvironment(.fresh)
}

#Preview("Inventory partly done") {
    TodayView()
        .previewEnvironment(.partialInventory)
}

#Preview("Several weeks of evidence") {
    TodayView()
        .previewEnvironment(.severalWeeks)
}

#Preview("Back after a long break") {
    TodayView()
        .previewEnvironment(.longBreak)
}
#endif
