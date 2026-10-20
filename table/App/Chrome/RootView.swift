import SwiftUI
import ChessCore

/// The table: the board in the middle, each player's panel on their own side.
struct RootView: View {
    let session: GameSession
    @Bindable var settings: SettingsStore

    @State private var settingsFor: PieceColor?
    @State private var revealed = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { proxy in
            let layout = TableLayout(size: proxy.size, safeArea: proxy.safeAreaInsets)
            let theme = settings.theme
            ZStack {
                table(theme, size: proxy.size)
                turnLight(theme, size: proxy.size)

                BoardView(session: session, settings: settings, size: layout.board, revealed: revealed)
                    .background(
                        RoundedRectangle(cornerRadius: layout.board * 0.011, style: .continuous)
                            .fill(theme.tableEdge)
                            .shadow(color: theme.boardShadow, radius: layout.board * 0.045, y: layout.board * 0.02)
                            .shadow(color: theme.boardShadow.opacity(0.5), radius: 2, y: 1)
                    )
                    .position(layout.boardCenter)

                seat(.white, layout: layout, theme: theme)
                seat(.black, layout: layout, theme: theme)
                    .rotationEffect(.degrees(180))

                if session.isResultPresented, let result = session.result {
                    ResultOverlay(result: result, theme: theme, boardSize: layout.board) {
                        session.feedback.ui()
                        session.newGame()
                    } dismiss: {
                        session.feedback.ui()
                        session.dismissResult()
                    }
                    .position(layout.boardCenter)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(5)
                }

                if let player = settingsFor {
                    Color.black.opacity(theme.isDark ? 0.45 : 0.22)
                        .ignoresSafeArea()
                        .onTapGesture { settingsFor = nil }
                        .transition(.opacity)
                        .zIndex(6)
                    SettingsCard(settings: settings, session: session, player: player) {
                        settingsFor = nil
                    }
                    .frame(maxHeight: min(proxy.size.height - 2 * layout.margin, 760))
                    .padding(layout.margin)
                    .rotationEffect(player == .black ? .degrees(180) : .zero)
                    .position(layout.boardCenter)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
                    .zIndex(7)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .animation(.easeInOut(duration: 0.24), value: settingsFor)
            .animation(.easeOut(duration: 0.4), value: session.isResultPresented)
            .animation(.easeInOut(duration: 0.4), value: settings.themeID)
        }
        .ignoresSafeArea()
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .preferredColorScheme(settings.theme.isDark ? .dark : .light)
        .onAppear {
            session.feedback.apply(settings)
            session.feedback.haptics.prepare()
            revealed = true
            applyLaunchOptions()
        }
        .onChange(of: settings.soundEnabled) { session.feedback.apply(settings) }
        .onChange(of: settings.volume) { session.feedback.apply(settings) }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: session.feedback.audio.resume()
            case .background, .inactive: session.save()
            @unknown default: break
            }
        }
    }

    /// The surface the board rests on, under a single lamp: a warm pool of light that falls
    /// off toward the edges of the room, with a fine grain so the falloff never bands.
    private func table(_ theme: BoardTheme, size: CGSize) -> some View {
        let reach = max(size.width, size.height) * 0.72
        return ZStack {
            theme.tableEdge
            RadialGradient(colors: [theme.tableCenter, theme.tableEdge.opacity(0)],
                           center: .center, startRadius: 0, endRadius: reach)
            Image("Grain")
                .resizable(resizingMode: .tile)
                .blendMode(theme.isDark ? .overlay : .multiply)
                .opacity(theme.grain * (theme.isDark ? 1.6 : 0.8))
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    /// Light gathers on the side of the player whose move it is.
    private func turnLight(_ theme: BoardTheme, size: CGSize) -> some View {
        let whiteToMove = session.sideToMove == .white
        let active = !session.isOver
        let reach = max(size.width, size.height) * 0.5
        let strength = theme.isDark ? 0.22 : 0.16
        return ZStack {
            RadialGradient(colors: [theme.turnGlow.opacity(strength), theme.turnGlow.opacity(0)],
                           center: UnitPoint(x: 0.5, y: 1.04), startRadius: 0, endRadius: reach)
                .opacity(active && whiteToMove ? 1 : 0)
            RadialGradient(colors: [theme.turnGlow.opacity(strength), theme.turnGlow.opacity(0)],
                           center: UnitPoint(x: 0.5, y: -0.04), startRadius: 0, endRadius: reach)
                .opacity(active && !whiteToMove ? 1 : 0)
        }
        .animation(.easeInOut(duration: 0.6), value: whiteToMove)
        .animation(.easeInOut(duration: 0.6), value: active)
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    /// One player's side of the table. Both are laid out as if for White; Black's is then
    /// rotated with its whole full-window layer, which places it opposite and facing Black.
    private func seat(_ color: PieceColor, layout: TableLayout, theme: BoardTheme) -> some View {
        ZStack(alignment: .topLeading) {
            Color.clear
            PlayerPanel(color: color, session: session, theme: theme, layout: layout) {
                settingsFor = color
            }
            .position(x: layout.panel.midX, y: layout.panel.midY)
        }
        .frame(width: layout.size.width, height: layout.size.height)
    }

    /// Launch arguments used by UI tests and screenshot runs.
    private func applyLaunchOptions() {
        let d = UserDefaults.standard
        if let sq = d.string(forKey: "select").flatMap({ Square($0) }) { session.select(sq) }
        if let who = d.string(forKey: "openSettings") { settingsFor = who == "black" ? .black : .white }
        if d.bool(forKey: "showResult"), session.result != nil { session.isResultPresented = true }
    }
}
