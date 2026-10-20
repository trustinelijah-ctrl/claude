import SwiftUI
import ChessCore

@main
struct TableApp: App {
    @State private var settings: SettingsStore
    @State private var session: GameSession

    init() {
        let feedback = FeedbackCoordinator()
        _settings = State(initialValue: SettingsStore())
        _session = State(initialValue: GameSession(feedback: feedback, initialGame: Self.launchGame()))
    }

    var body: some Scene {
        WindowGroup {
            SimulatedWindow {
                RootView(session: session, settings: settings)
            }
        }
    }

    /// `-fresh YES` starts from the opening position; `-moves "e2e4 e7e5 ..."` sets up a game.
    /// Used by UI tests and screenshot runs. Normal launches resume the saved game.
    private static func launchGame() -> ChessGame? {
        let d = UserDefaults.standard
        if let list = d.string(forKey: "moves") {
            var g = ChessGame()
            for uci in list.split(separator: " ") {
                if let m = Move(uci: String(uci)) { g.play(m) }
            }
            return g
        }
        return d.bool(forKey: "fresh") ? ChessGame() : nil
    }
}

/// For screenshot runs only: confines the app to a Split View or Stage Manager sized region
/// (`-simulateWindow half|third|square`) so those layouts can be checked without multitasking.
struct SimulatedWindow<Content: View>: View {
    @ViewBuilder let content: Content
    private let mode = UserDefaults.standard.string(forKey: "simulateWindow")

    var body: some View {
        if let mode {
            GeometryReader { proxy in
                let s = proxy.size
                let size: CGSize = switch mode {
                case "third": CGSize(width: (s.width * 0.32).rounded(), height: s.height)
                case "square": CGSize(width: (min(s.width, s.height) * 0.94).rounded(), height: (min(s.width, s.height) * 0.86).rounded())
                default: CGSize(width: (s.width * 0.5 - 5).rounded(), height: s.height)
                }
                content
                    .frame(width: size.width, height: size.height)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .frame(width: s.width, height: s.height, alignment: mode == "square" ? .center : .leading)
            }
            .background(Color(white: 0.06))
            .ignoresSafeArea()
        } else {
            content
        }
    }
}
