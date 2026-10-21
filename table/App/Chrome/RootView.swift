import SwiftUI
import ChessCore

/// The whole window is the board. The grid is set into a surface that fills the screen;
/// each player's end holds their name, tray and pins.
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
            let bottom: PieceColor = settings.boardFlipped ? .black : .white
            ZStack(alignment: .topLeading) {
                TableField(theme: theme, layout: layout)
                turnLight(theme, size: proxy.size, bottom: bottom)

                PlayerZone(color: bottom, session: session, settings: settings, layout: layout) {
                    settingsFor = bottom
                }
                PlayerZone(color: bottom.opposite, session: session, settings: settings, layout: layout,
                           facesNearPlayer: settings.isAgainstComputer) {
                    settingsFor = bottom.opposite
                }
                .rotationEffect(.degrees(180))

                BoardView(session: session, settings: settings, layout: layout, revealed: revealed)

                if session.isResultPresented, let result = session.result {
                    ResultOverlay(result: result, theme: theme, boardSize: layout.board,
                                  mirrored: !settings.isAgainstComputer, viewer: bottom) {
                        session.feedback.ui()
                        session.newGame()
                    } dismiss: {
                        session.feedback.ui()
                        session.dismissResult()
                    }
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
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
                    .frame(maxHeight: min(proxy.size.height - 40, 820))
                    .padding(20)
                    .rotationEffect(player == bottom ? .zero : .degrees(180))
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
                    .zIndex(7)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .animation(.easeInOut(duration: 0.24), value: settingsFor)
            .animation(.easeOut(duration: 0.4), value: session.isResultPresented)
            .animation(.easeInOut(duration: 0.4), value: settings.themeID)
            .animation(.spring(response: 0.6, dampingFraction: 0.86), value: settings.boardFlipped)
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
            syncOpponent()
        }
        .onChange(of: settings.soundEnabled) { session.feedback.apply(settings) }
        .onChange(of: settings.volume) { session.feedback.apply(settings) }
        .onChange(of: settings.opponent) { syncOpponent() }
        .onChange(of: settings.botLevel) { syncOpponent() }
        .onChange(of: settings.humanColor) { syncOpponent() }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: session.feedback.audio.resume()
            case .background, .inactive: session.save()
            @unknown default: break
            }
        }
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
            // Gilt tooling around the edge of the whole board-that-is-the-screen.
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(theme.inlay.opacity(0.55), lineWidth: 1)
                .padding(9)
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(theme.inlay.opacity(0.28), lineWidth: 0.6)
                .padding(14)
        }
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
