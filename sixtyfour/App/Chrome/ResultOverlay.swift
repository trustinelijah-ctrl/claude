import SwiftUI
import ChessCore

enum ResultText {
    static func headline(_ r: GameResult) -> String {
        switch r {
        case .checkmate: return "Checkmate"
        case .resignation: return "Resignation"
        case .timeout: return "Time"
        case .draw(let reason):
            switch reason {
            case .stalemate: return "Stalemate"
            default: return "Draw"
            }
        }
    }

    static func detail(_ r: GameResult) -> String {
        switch r {
        case .checkmate(let w): return "\(name(w)) wins"
        case .resignation(let w): return "\(name(w.opposite)) resigned"
        case .timeout(let w): return "\(name(w.opposite)) ran out of time"
        case .draw(let reason):
            switch reason {
            case .stalemate: return "No legal moves"
            case .insufficientMaterial: return "Not enough material to mate"
            case .threefoldRepetition: return "Threefold repetition"
            case .fivefoldRepetition: return "Fivefold repetition"
            case .fiftyMoveRule: return "Fifty-move rule"
            case .seventyFiveMoveRule: return "Seventy-five-move rule"
            case .agreement: return "By agreement"
            case .timeoutVsInsufficientMaterial: return "Time ran out, but mate was impossible"
            }
        }
    }

    static func name(_ c: PieceColor) -> String { c == .white ? "White" : "Black" }
}

/// The table dims around the board when a game ends, and for a decisive result, gold dust
/// drifts down through the lamplight.
struct ResultStage: View {
    let theme: BoardTheme
    let decisive: Bool

    var body: some View {
        ZStack {
            RadialGradient(colors: [.black.opacity(0.12), .black.opacity(theme.isDark ? 0.72 : 0.5)],
                           center: .center, startRadius: 40, endRadius: 900)
            if decisive { GoldDust() }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Flecks of gold leaf, falling and turning, catching the light as they go.
struct GoldDust: View {
    private struct Fleck {
        let x: Double, delay: Double, speed: Double, size: Double, sway: Double, spin: Double, phase: Double, hue: Int
    }

    @State private var start = Date()
    private let flecks: [Fleck] = {
        var rng = SystemRandomNumberGenerator()
        return (0..<44).map { _ in
            Fleck(x: .random(in: 0...1, using: &rng), delay: .random(in: 0...1.6, using: &rng),
                  speed: .random(in: 0.12...0.28, using: &rng), size: .random(in: 3...8, using: &rng),
                  sway: .random(in: 8...30, using: &rng), spin: .random(in: 1.5...5, using: &rng),
                  phase: .random(in: 0...(2 * .pi), using: &rng), hue: .random(in: 0...2, using: &rng))
        }
    }()
    private let golds = [Color(hex: 0xF7E3A6), Color(hex: 0xD9B25E), Color(hex: 0xB8873A)]

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSince(start)
            Canvas { ctx, size in
                guard t < 4.5 else { return }
                for f in flecks {
                    let life = t - f.delay
                    guard life > 0 else { continue }
                    let y = -20 + life * f.speed * size.height
                    guard y < size.height + 20 else { continue }
                    let x = f.x * size.width + sin(life * 1.3 + f.phase) * f.sway
                    // Flat leaf turning in the air: its width swells and thins as it spins.
                    let turn = abs(cos(life * f.spin + f.phase))
                    let fade = min(1, life * 3) * max(0, min(1, (4.5 - t) / 1.2))
                    var leaf = ctx
                    leaf.translateBy(x: x, y: y)
                    leaf.rotate(by: .radians(life * f.spin * 0.6 + f.phase))
                    leaf.opacity = fade * (0.55 + 0.45 * turn)
                    let rect = CGRect(x: -f.size / 2, y: -f.size * 0.3, width: f.size * max(0.2, turn), height: f.size * 0.6)
                    leaf.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(golds[f.hue]))
                }
            }
        }
    }
}

/// The end of the game: the result in a line, and a way straight into the next one.
/// Written once for each player when two people share the table, so both read it from their seat.
struct ResultOverlay: View {
    let result: GameResult
    let session: GameSession
    let settings: SettingsStore
    let boardSize: CGFloat
    /// The player at the bottom of the screen.
    var viewer: PieceColor = .white
    let playAgain: () -> Void
    let dismiss: () -> Void
    var replay: (() -> Void)?

    @State private var shown = false

    private var theme: BoardTheme { settings.theme }
    private var mirrored: Bool { !settings.isAgainstComputer }

    var body: some View {
        VStack(spacing: 0) {
            if mirrored {
                half(for: viewer.opposite)
                    .rotationEffect(.degrees(180))
                Rectangle()
                    .fill(theme.accent.opacity(0.35))
                    .frame(height: 0.75)
                    .padding(.horizontal, 24)
            }
            half(for: viewer)
        }
        .frame(width: min(boardSize * 0.7, 420))
        .background(card)
        .scaleEffect(shown ? 1 : 0.94)
        .opacity(shown ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { shown = true }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("result")
    }

    private var card: some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
        return shape
            .fill(theme.isDark ? Color(hex: 0x1E120B) : Color(hex: 0xFBF8F2))
            .overlay(shape.strokeBorder(LinearGradient(colors: [Color(hex: 0xF3DFA8), theme.accent.opacity(0.6), Color(hex: 0x8A672E)],
                                                       startPoint: .top, endPoint: .bottom), lineWidth: 1))
            .shadow(color: .black.opacity(0.5), radius: 36, y: 10)
    }

    private func half(for seat: PieceColor) -> some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text(headline(for: seat))
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(theme.ink)
                Text(subline)
                    .font(.system(size: 15))
                    .foregroundStyle(theme.inkSecondary)
                    .multilineTextAlignment(.center)
                if let streak {
                    Text(streak)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(theme.accent)
                        .padding(.top, 2)
                }
            }
            HStack(spacing: 10) {
                if let replay, seat == viewer {
                    secondary("Review", action: replay)
                } else {
                    secondary("Close", action: dismiss)
                }
                Button(action: playAgain) {
                    Text("Rematch")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Brand.brown)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(Capsule().fill(Brand.cream))
                        .overlay(Capsule().strokeBorder(theme.accent, lineWidth: 1))
                }
                .buttonStyle(PressScaleStyle())
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 22)
        .overlay(alignment: .topTrailing) {
            if replay != nil && seat == viewer {
                Button(action: dismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(theme.inkSecondary)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Close")
            }
        }
    }

    private func secondary(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(theme.ink)
                .frame(maxWidth: .infinity, minHeight: 46)
                .overlay(Capsule().strokeBorder(theme.accent.opacity(0.5), lineWidth: 1))
                .contentShape(Capsule())
        }
        .buttonStyle(PressScaleStyle())
    }

    // MARK: Words

    private func headline(for seat: PieceColor) -> String {
        guard let w = result.winner else { return "Draw" }
        if settings.isAgainstComputer { return w == settings.computerColor ? "64 wins" : "You win" }
        return w == seat ? "You win" : "\(ResultText.name(w)) wins"
    }

    private var subline: String {
        let moves = (session.game.history.count + 1) / 2
        let count = "\(moves) \(moves == 1 ? "move" : "moves")"
        switch result {
        case .checkmate: return "Checkmate · \(count)"
        case .resignation(let w):
            if settings.isAgainstComputer { return w == settings.computerColor ? "You resigned · \(count)" : "64 resigned · \(count)" }
            return "\(ResultText.name(w.opposite)) resigned · \(count)"
        case .timeout(let w):
            if settings.isAgainstComputer, w == settings.computerColor { return "Your time ran out" }
            return "\(ResultText.name(w.opposite))'s time ran out"
        case .draw: return ResultText.detail(result)
        }
    }

    /// Against the computer, a winning run is worth a mention.
    private var streak: String? {
        guard let r = session.ending?.record, r.streak >= 2 else { return nil }
        return "\(r.streak) wins in a row against \(settings.botLevel.title)"
    }
}
