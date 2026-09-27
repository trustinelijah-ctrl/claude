import SwiftUI
import SwiftData
import PianoCore

struct RootView: View {
    @Environment(AppState.self) private var app
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false

    var body: some View {
        @Bindable var app = app
        TabView(selection: $app.tab) {
            TodayView()
                .tabItem { Label("Today", systemImage: "sun.horizon") }
                .tag(AppTab.today)
            PracticeHomeView()
                .tabItem { Label("Practice", systemImage: "pianokeys") }
                .tag(AppTab.practice)
            SkillMapView()
                .tabItem { Label("Map", systemImage: "map") }
                .tag(AppTab.map)
            JournalView()
                .tabItem { Label("Journal", systemImage: "book.closed") }
                .tag(AppTab.journal)
        }
        .sheet(item: $app.sheet, onDismiss: app.presentPending) { sheet in
            switch sheet {
            case .setup(let focusID): SessionSetupView(preselectedTaskID: focusID)
            case .inventory: InventoryView()
            case .settings: SettingsView()
            }
        }
        .fullScreenCover(item: $app.cover, onDismiss: app.presentPending) { cover in
            switch cover {
            case .session(let session): ActiveSessionView(session: session)
            case .justPlay(let session): JustPlayView(session: session)
            case .welcome: WelcomeView()
            }
        }
        .task {
            SkillSeeder.seedIfNeeded(context)
            if !hasSeenWelcome { app.cover = .welcome }
        }
        .onChange(of: scenePhase) { _, phase in
            // Belt and braces on top of SwiftData's autosave: anything typed
            // is on disk before the app can be suspended or killed.
            if phase != .active { try? context.save() }
        }
    }
}

/// Shown at the bottom of every tab while a session is running or paused, so
/// leaving the session screen never loses it.
struct ActiveSessionBar: View {
    @Environment(AppState.self) private var app
    @Query(filter: #Predicate<PracticeSession> { $0.endedAt == nil }, sort: \PracticeSession.startedAt, order: .reverse)
    private var active: [PracticeSession]

    var body: some View {
        if let session = active.first {
            Button { app.open(session) } label: {
                HStack(spacing: 12) {
                    Image(systemName: session.isPaused ? "pause.circle.fill" : "waveform")
                        .font(.title3)
                        .foregroundStyle(Palette.onForest)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.kind == .justPlay ? "Just playing" : "Session in progress")
                            .font(.subheadline.weight(.semibold))
                        TimelineView(.periodic(from: .now, by: 1)) { timeline in
                            Text(session.isPaused
                                 ? "Paused at \(SessionClock.format(session.elapsed(at: timeline.date)))"
                                 : SessionClock.format(session.elapsed(at: timeline.date)))
                                .font(.subheadline.monospacedDigit())
                        }
                    }
                    .foregroundStyle(Palette.onForest)
                    Spacer()
                    Text("Return")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.onForest)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(Palette.forest, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(.horizontal, 12)
                .padding(.bottom, 6)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(session.kind == .justPlay ? "Just playing. Return." : "Session in progress. Return to session.")
        }
    }
}

extension View {
    /// Adds the active-session bar above the tab bar.
    func activeSessionBar() -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) { ActiveSessionBar() }
    }
}
