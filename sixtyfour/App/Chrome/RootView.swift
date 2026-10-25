import SwiftUI
import StoreKit
import ChessCore

/// The whole window is the board. The grid is set into a surface that fills the screen;
/// each player's end holds their name, tray and pins.
struct RootView: View {
    let session: GameSession
    @Bindable var settings: SettingsStore
    let pro: ProStore
    let account: AccountStore

    @State private var settingsFor: PieceColor?
    @State private var capturesFor: PieceColor?
    @State private var paywallOpen = false
    @State private var libraryOpen = false
    @State private var replaying: SavedGame?
    @State private var revealed = false
    @State private var screen: Screen = RootView.initialScreen

    enum Screen { case home, board, learn }

    /// Opens on the home screen, except for test runs that set up a game on the board.
    private static var initialScreen: Screen {
        let d = UserDefaults.standard
        if let home = d.string(forKey: "home") { return ["YES", "1", "true"].contains(home) ? .home : .board }
        if d.string(forKey: "learn") != nil { return .learn }
        return d.bool(forKey: "fresh") || d.string(forKey: "moves") != nil ? .board : .home
    }
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.requestReview) private var requestReview

    var body: some View {
        GeometryReader { proxy in
            let layout = TableLayout(size: proxy.size, safeArea: proxy.safeAreaInsets)
            let theme = settings.theme
            let bottom: PieceColor = settings.boardFlipped ? .black : .white
            ZStack(alignment: .topLeading) {
                TableField(theme: theme, layout: layout)
                turnLight(theme, size: proxy.size, bottom: bottom)

                PlayerZone(color: bottom, session: session, settings: settings, layout: layout,
                           showCaptures: { capturesFor = bottom }, requestHint: hint, goHome: leaveToHome) {
                    settingsFor = bottom
                }
                PlayerZone(color: bottom.opposite, session: session, settings: settings, layout: layout,
                           facesNearPlayer: settings.isAgainstComputer,
                           showCaptures: { capturesFor = bottom.opposite }, requestHint: hint, goHome: leaveToHome) {
                    settingsFor = bottom.opposite
                }
                .rotationEffect(.degrees(180))

                BoardView(session: session, settings: settings, layout: layout, revealed: revealed)

                if session.isResultPresented, let result = session.result {
                    ResultStage(theme: theme, decisive: result.winner != nil)
                        .transition(.opacity)
                        .zIndex(4.8)
                    ResultOverlay(result: result, session: session, settings: settings,
                                  boardSize: layout.board, viewer: bottom) {
                        session.feedback.ui()
                        session.newGame()
                    } dismiss: {
                        session.feedback.ui()
                        session.dismissResult()
                    } replay: {
                        session.feedback.ui()
                        session.dismissResult()
                        replaying = session.library.games.first
                    }
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(5)
                }

                if screen == .home {
                    HomeView(session: session, settings: settings, pro: pro, feedback: session.feedback,
                             resume: { screen = .board },
                             playFriend: { start(against: nil) },
                             playComputer: { start(against: settings.botLevel) },
                             learn: { screen = .learn },
                             games: { libraryOpen = true },
                             options: { settingsFor = bottom },
                             upgrade: { openPaywall("home") })
                        .transition(.opacity)
                        .zIndex(3)
                }

                if screen == .learn {
                    PuzzleView(pro: pro, feedback: session.feedback, unlock: { openPaywall("learn") }) {
                        screen = .home
                    }
                    .transition(.opacity)
                    .zIndex(3)
                }

                if let owner = capturesFor {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .overlay(Color.black.opacity(theme.isDark ? 0.25 : 0.08))
                        .ignoresSafeArea()
                        .onTapGesture { capturesFor = nil }
                        .transition(.opacity)
                        .accessibilityHidden(true)
                        .zIndex(4)
                    CapturesPanel(owner: owner, session: session, settings: settings) {
                        session.feedback.ui()
                        capturesFor = nil
                    }
                    .frame(maxWidth: min(proxy.size.width - 32, 640))
                    .rotationEffect(owner != bottom && !settings.isAgainstComputer ? .degrees(180) : .zero)
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(4.5)
                }

                if let player = settingsFor {
                    Color.black.opacity(theme.isDark ? 0.45 : 0.22)
                        .ignoresSafeArea()
                        .onTapGesture { settingsFor = nil }
                        .transition(.opacity)
                        .zIndex(6)
                    SettingsCard(settings: settings, session: session, player: player, pro: pro, account: account,
                                 showPaywall: { openPaywall("options") },
                                 showLibrary: { settingsFor = nil; libraryOpen = true },
                                 showWelcome: { settingsFor = nil; account.replayWelcome() },
                                 goHome: screen == .board ? leaveToHome : nil) {
                        settingsFor = nil
                    }
                    .frame(maxHeight: min(proxy.size.height - 40, 820))
                    .padding(20)
                    .rotationEffect(player == bottom ? .zero : .degrees(180))
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
                    .zIndex(7)
                }

                if libraryOpen {
                    dimmer(theme) { libraryOpen = false }.zIndex(8)
                    LibraryView(library: session.library, pro: pro, theme: theme, feedback: session.feedback,
                                open: { saved in libraryOpen = false; replaying = saved },
                                unlock: { openPaywall("library") },
                                close: { libraryOpen = false })
                        .padding(20)
                        .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                        .zIndex(8.5)
                }

                if paywallOpen {
                    Rectangle().fill(.ultraThinMaterial)
                        .overlay(Color.black.opacity(0.35))
                        .ignoresSafeArea()
                        .onTapGesture { paywallOpen = false }
                        .transition(.opacity)
                        .zIndex(12)
                    PaywallSheet(pro: pro, theme: theme, feedback: session.feedback) { paywallOpen = false }
                        .frame(maxHeight: proxy.size.height - proxy.safeAreaInsets.top - proxy.safeAreaInsets.bottom - 24)
                        .padding(.horizontal, 20)
                        .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                        .zIndex(12.5)
                }

                if let welcome = pro.welcome {
                    ProWelcome(welcome: welcome, feedback: session.feedback) { pro.welcome = nil }
                        .transition(.opacity.combined(with: .scale(scale: 1.02)))
                        .zIndex(13)
                }

                if let saved = replaying {
                    ReplayView(saved: saved, theme: theme, feedback: session.feedback, pro: pro,
                               unlock: { openPaywall("review") }) { replaying = nil }
                        .transition(.opacity)
                        .zIndex(10)
                }

                if !account.hasOnboarded {
                    OnboardingView(pro: pro, account: account, feedback: session.feedback,
                                   showPlans: { openPaywall("welcome") }) {
                        // 64 Pro is offered once, right after the welcome, then never pushed again.
                        let key = "paywall.afterWelcome"
                        guard !pro.isPro, !UserDefaults.standard.bool(forKey: key),
                              !ProcessInfo.processInfo.arguments.contains("-onboarded") else { return }
                        UserDefaults.standard.set(true, forKey: key)
                        Analytics.signal("onboarding.completed")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { openPaywall("after-welcome") }
                    }
                        .transition(.opacity)
                        .zIndex(11)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .animation(.easeInOut(duration: 0.24), value: settingsFor)
            .animation(.easeInOut(duration: 0.35), value: screen)
            .animation(.easeInOut(duration: 0.28), value: libraryOpen)
            .animation(.easeInOut(duration: 0.28), value: paywallOpen)
            .animation(.easeInOut(duration: 0.4), value: pro.welcome)
            .animation(.easeInOut(duration: 0.35), value: replaying)
            .animation(.easeInOut(duration: 0.6), value: account.hasOnboarded)
            .animation(.easeInOut(duration: 0.28), value: capturesFor)
            .animation(.easeOut(duration: 0.4), value: session.isResultPresented)
            .animation(.easeInOut(duration: 0.4), value: settings.themeID)
            .animation(.spring(response: 0.6, dampingFraction: 0.86), value: settings.boardFlipped)
        }
        .ignoresSafeArea()
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .environment(\.pieceSet, settings.pieceSet)
        .preferredColorScheme(settings.theme.isDark || !account.hasOnboarded ? .dark : .light)
        .onAppear {
            session.feedback.apply(settings)
            session.feedback.haptics.prepare()
            revealed = true
            session.configure(timeControl: settings.timeControl)
            applyLaunchOptions()
            syncOpponent()
        }
        .onChange(of: settings.soundEnabled) { session.feedback.apply(settings) }
        .onChange(of: settings.volume) { session.feedback.apply(settings) }
        .onChange(of: settings.ambience) {
            session.feedback.apply(settings)
            Analytics.signal("ambience.selected", ["scene": settings.ambience.rawValue])
        }
        .onChange(of: settings.ambienceVolume) { session.feedback.apply(settings) }
        .onChange(of: settings.hapticsEnabled) { session.feedback.apply(settings) }
        .onChange(of: settings.playInSilentMode) { session.feedback.apply(settings) }
        .onChange(of: settings.opponent) { syncOpponent() }
        .onChange(of: settings.botLevel) { syncOpponent() }
        .onChange(of: settings.humanColor) { syncOpponent() }
        .onChange(of: settings.timeControl) { session.configure(timeControl: settings.timeControl) }
        .onChange(of: overlayOpen) { _, open in
            if open { session.pauseClock() } else { session.resumeClock() }
        }
        .onChange(of: keepAwake, initial: true) { _, awake in
            UIApplication.shared.isIdleTimerDisabled = awake
        }
        .onChange(of: session.isResultPresented) { _, shown in
            if shown, let r = session.result {
                let outcome = r.winner == nil ? "draw" : (settings.isAgainstComputer ? (r.winner == settings.humanColor ? "win" : "loss") : "decisive")
                Analytics.signal("game.finished", ["opponent": settings.isAgainstComputer ? settings.botLevel.rawValue : "friend",
                                                   "outcome": outcome])
            }
            // A win is the moment to ask for a rating, at most once per version.
            guard shown, ReviewPrompt.mayAsk, let r = session.result, let winner = r.winner else { return }
            if settings.isAgainstComputer && winner != settings.humanColor { return }
            ReviewPrompt.asked()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { requestReview() }
        }
        .onChange(of: pro.isPro) { _, isPro in
            if isPro { paywallOpen = false } else { settings.dropProChoices() }
        }
        .task { await account.checkAppleCredential() }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                session.feedback.audio.resume()
                if !overlayOpen { session.resumeClock() }
            case .background, .inactive:
                session.pauseClock()
                session.save()
            @unknown default: break
            }
        }
    }

    /// Anything covering the board stops the clock.
    private var overlayOpen: Bool {
        settingsFor != nil || capturesFor != nil || paywallOpen || libraryOpen || replaying != nil || pro.welcome != nil
            || !account.hasOnboarded || screen != .board
    }

    /// The screen stays on while a game or a puzzle is under way, so nobody has to change Auto-Lock.
    private var keepAwake: Bool {
        scenePhase == .active && ((screen == .board && !session.isOver) || screen == .learn)
    }

    private func leaveToHome() {
        settingsFor = nil
        screen = .home
    }

    /// A new game from the home screen: against the computer at `level`, or two people.
    private func openPaywall(_ source: String) {
        Analytics.signal("paywall.shown", ["source": source])
        paywallOpen = true
    }

    private func start(against level: BotLevel?) {
        Analytics.signal("game.started", ["opponent": level?.rawValue ?? "friend"])
        settings.opponent = level == nil ? .friend : .computer
        if let level { settings.botLevel = level }
        syncOpponent()
        session.newGame()
        screen = .board
    }

    /// Hints come with 64 Pro.
    private func hint() {
        if pro.isPro { session.requestHint() } else { openPaywall("hint") }
    }

    private func dimmer(_ theme: BoardTheme, close: @escaping () -> Void) -> some View {
        Color.black.opacity(theme.isDark ? 0.45 : 0.22)
            .ignoresSafeArea()
            .onTapGesture(perform: close)
            .transition(.opacity)
    }

    private func syncOpponent() {
        if let c = settings.computerColor {
            session.configure(computer: (c, settings.botLevel))
        } else {
            session.configure(computer: nil)
        }
    }

    /// Light gathers at the end of the player whose move it is.
    private func turnLight(_ theme: BoardTheme, size: CGSize, bottom: PieceColor) -> some View {
        let bottomToMove = session.sideToMove == bottom
        let active = !session.isOver
        let reach = max(size.width, size.height) * 0.42
        let strength = theme.isDark ? 0.2 : 0.14
        return ZStack {
            RadialGradient(colors: [theme.turnGlow.opacity(strength), theme.turnGlow.opacity(0)],
                           center: UnitPoint(x: 0.5, y: 1.02), startRadius: 0, endRadius: reach)
                .opacity(active && bottomToMove ? 1 : 0)
            RadialGradient(colors: [theme.turnGlow.opacity(strength), theme.turnGlow.opacity(0)],
                           center: UnitPoint(x: 0.5, y: -0.02), startRadius: 0, endRadius: reach)
                .opacity(active && !bottomToMove ? 1 : 0)
        }
        .animation(.easeInOut(duration: 0.6), value: bottomToMove)
        .animation(.easeInOut(duration: 0.6), value: active)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Launch arguments used by UI tests and screenshot runs.
    private func applyLaunchOptions() {
        let d = UserDefaults.standard
        if let sq = d.string(forKey: "select").flatMap({ Square($0) }) { session.select(sq) }
        if let who = d.string(forKey: "openSettings") { settingsFor = who == "black" ? .black : .white }
        if let who = d.string(forKey: "showCaptures") { capturesFor = who == "black" ? .black : .white }
        if d.bool(forKey: "seedLibrary"), session.library.games.isEmpty {
            session.library.add(session.game, level: settings.isAgainstComputer ? settings.botLevel : nil,
                                humanColor: settings.isAgainstComputer ? settings.humanColor : nil, duration: 754)
        }
        if d.bool(forKey: "showPaywall") { paywallOpen = true }
        if let w = d.string(forKey: "showProWelcome") {
            pro.welcome = w == "restored" ? .restored : .subscribed(trialEnds: w == "trial" ? Date().addingTimeInterval(7 * 86_400) : nil)
        }
        if d.bool(forKey: "showLibrary") { libraryOpen = true }
        if d.bool(forKey: "showReplay") { replaying = session.library.games.first }
        if d.bool(forKey: "showResult"), session.result != nil { session.isResultPresented = true }
    }
}

/// The board's own surface: the material filling the screen around the grid, lit by a lamp
/// over the board, with a fine gilt line tooled around the edge of the whole device.
struct TableField: View {
    let theme: BoardTheme
    let layout: TableLayout

    var body: some View {
        let size = layout.size
        let b = layout.boardRect
        ZStack(alignment: .topLeading) {
            Image(theme.fieldImage)
                .resizable()
                .interpolation(.high)
                .scaledToFill()
                .frame(width: size.width, height: size.height)
                .clipped()
            // The lamp: brightest over the board, falling away toward the ends.
            RadialGradient(colors: [Color.white.opacity(theme.isDark ? 0.07 : 0.12), .clear, .black.opacity(theme.isDark ? 0.5 : 0.12)],
                           center: .center, startRadius: 0, endRadius: max(size.width, size.height) * 0.62)
            Image("Grain")
                .resizable(resizingMode: .tile)
                .blendMode(theme.isDark ? .overlay : .multiply)
                .opacity(theme.grain * (theme.isDark ? 1.6 : 0.8))
            // The grid is set into the surface: a fine dark groove around it.
            RoundedRectangle(cornerRadius: b.width * 0.011, style: .continuous)
                .stroke(Color.black.opacity(theme.isDark ? 0.75 : 0.3), lineWidth: 3)
                .blur(radius: 2.5)
                .frame(width: b.width, height: b.height)
                .offset(x: b.minX, y: b.minY)
            if Self.quietEnds {
                // Layout preview: the ends fall into shadow so the board reads as the one object,
                // and the gilt moves to a fine inlay around the grid.
                Path { p in
                    p.addRect(CGRect(origin: .zero, size: size))
                    p.addRect(b)
                }
                .fill(Color.black.opacity(theme.isDark ? 0.3 : 0.38), style: FillStyle(eoFill: true))
                Rectangle()
                    .stroke(theme.inlay.opacity(0.85), lineWidth: 1.5)
                    .frame(width: b.width, height: b.height)
                    .offset(x: b.minX, y: b.minY)
            }
            // Gilt tooling around each player's end. It frames the strips and stops at the board,
            // never crossing it.
            ForEach(Array(endPanels(size: size, board: b).enumerated()), id: \.offset) { _, panel in
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(theme.inlay.opacity(0.55), lineWidth: 1)
                    .frame(width: panel.width, height: panel.height)
                    .offset(x: panel.minX, y: panel.minY)
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(theme.inlay.opacity(0.28), lineWidth: 0.6)
                    .frame(width: panel.width - 10, height: panel.height - 10)
                    .offset(x: panel.minX + 5, y: panel.minY + 5)
            }
        }
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Layout preview switch (`-quietEnds YES`).
    static let quietEnds = UserDefaults.standard.bool(forKey: "quietEnds")

    /// The space at each end of the board, inset from the screen edge and from the board.
    private func endPanels(size: CGSize, board b: CGRect) -> [CGRect] {
        if Self.quietEnds { return [] }
        let edge: CGFloat = 9, gap: CGFloat = 7
        var panels: [CGRect] = []
        if layout.arrangement == .ends {
            let top = CGRect(x: edge, y: edge, width: size.width - 2 * edge, height: b.minY - gap - edge)
            let bottom = CGRect(x: edge, y: b.maxY + gap, width: size.width - 2 * edge, height: size.height - b.maxY - gap - edge)
            panels = [top, bottom]
        } else {
            let left = CGRect(x: edge, y: edge, width: b.minX - gap - edge, height: size.height - 2 * edge)
            let right = CGRect(x: b.maxX + gap, y: edge, width: size.width - b.maxX - gap - edge, height: size.height - 2 * edge)
            panels = [left, right]
        }
        return panels.filter { $0.width > 30 && $0.height > 30 }
    }
}
