import SwiftUI
import ChessCore

enum ResultText {
    static func headline(_ r: GameResult) -> String {
        switch r {
        case .checkmate: return "Checkmate"
        case .resignation: return "Resignation"
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
        case .resignation(let w): return "\(name(w.opposite)) resigns · \(name(w)) wins"
        case .draw(let reason):
            switch reason {
            case .stalemate: return "No legal moves, and no check"
            case .insufficientMaterial: return "Neither side can mate"
            case .threefoldRepetition: return "Threefold repetition"
            case .fivefoldRepetition: return "Fivefold repetition"
            case .fiftyMoveRule: return "Fifty moves without a capture or pawn move"
            case .seventyFiveMoveRule: return "Seventy-five moves without progress"
            case .agreement: return "By agreement"
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
        return (0..<120).map { _ in
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
                guard t < 7 else { return }
                for f in flecks {
                    let life = t - f.delay
                    guard life > 0 else { continue }
                    let y = -20 + life * f.speed * size.height
                    guard y < size.height + 20 else { continue }
                    let x = f.x * size.width + sin(life * 1.3 + f.phase) * f.sway
                    // Flat leaf turning in the air: its width swells and thins as it spins.
                    let turn = abs(cos(life * f.spin + f.phase))
                    let fade = min(1, life * 3) * max(0, min(1, (7 - t) / 1.5))
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

/// The end of the game: who won and how, what it took, and a way straight into the next.
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

    @State private var shown = false

    private var theme: BoardTheme { settings.theme }
    private var mirrored: Bool { !settings.isAgainstComputer }
    private var compact: Bool { boardSize < 560 }

    var body: some View {
        let width = min(boardSize * 0.8, 520)
        VStack(spacing: 0) {
            if mirrored {
                half(for: viewer.opposite)
                    .rotationEffect(.degrees(180))
                Rectangle()
                    .fill(LinearGradient(colors: [.clear, theme.accent.opacity(0.6), .clear],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(height: 1)
                    .padding(.horizontal, 28)
            }
            half(for: viewer)
        }
        .frame(width: width)
        .background(card)
        .scaleEffect(shown ? 1 : 0.9)
        .opacity(shown ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) { shown = true }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("result")
    }

    private var card: some View {
        let shape = RoundedRectangle(cornerRadius: 30, style: .continuous)
        return ZStack {
            shape.fill(theme.isDark ? Color(hex: 0x16110D) : Color(hex: 0xFBF8F2))
            shape.fill(RadialGradient(colors: [theme.accent.opacity(theme.isDark ? 0.16 : 0.1), .clear],
                                      center: .center, startRadius: 0, endRadius: 320))
            Image("Grain").resizable(resizingMode: .tile)
                .blendMode(theme.isDark ? .overlay : .multiply).opacity(0.25)
                .clipShape(shape)
            shape.strokeBorder(LinearGradient(colors: [Color(hex: 0xF3DFA8), theme.accent.opacity(0.6), Color(hex: 0x8A672E)],
                                              startPoint: .top, endPoint: .bottom), lineWidth: 1.2)
            shape.inset(by: 6).strokeBorder(theme.accent.opacity(0.22), lineWidth: 0.6)
        }
        .shadow(color: .black.opacity(0.55), radius: 50, y: 12)
    }

    // MARK: One seat's half

    private func half(for seat: PieceColor) -> some View {
        VStack(spacing: compact ? 10 : 16) {
            crest
            VStack(spacing: compact ? 2 : 4) {
                Text(ResultText.headline(result).uppercased())
                    .font(Typeface.display(compact ? 13 : 15, bold: true))
                    .tracking(compact ? 4 : 6)
                    .foregroundStyle(theme.accent)
                Text(headline(for: seat))
                    .font(Typeface.display(compact ? 38 : 54))
                    .foregroundStyle(theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(subline(for: seat))
                    .font(Typeface.italic(compact ? 17 : 21))
                    .foregroundStyle(theme.inkSecondary)
                    .multilineTextAlignment(.center)
            }
            stats
            if let note = recordNote(for: seat) {
                Text(note)
                    .font(Typeface.italic(compact ? 16 : 18))
                    .foregroundStyle(theme.accent)
                    .multilineTextAlignment(.center)
            }
            buttons
        }
        .padding(.horizontal, compact ? 20 : 30)
        .padding(.vertical, compact ? 16 : 26)
    }

    /// The winning king on a pool of light; for a draw, both kings side by side.
    private var crest: some View {
        let s: CGFloat = compact ? 60 : 92
        return ZStack {
            Circle()
                .fill(RadialGradient(colors: [theme.accent.opacity(0.45), .clear], center: .center,
                                     startRadius: 0, endRadius: s * 0.75))
                .frame(width: s * 1.6, height: s * 1.6)
                .scaleEffect(shown ? 1 : 0.4)
                .animation(.easeOut(duration: 1.1).delay(0.15), value: shown)
            if let w = result.winner {
                StandingPiece(piece: Piece(w, .king), size: s, shadow: 0.45)
                    .offset(y: shown ? 0 : 18)
                    .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.12), value: shown)
            } else {
                HStack(spacing: -s * 0.3) {
                    StandingPiece(piece: Piece(.white, .king), size: s * 0.85, shadow: 0.4)
                    StandingPiece(piece: Piece(.black, .king), size: s * 0.85, shadow: 0.4)
                }
            }
        }
        .frame(height: s * 1.05)
    }

    private var stats: some View {
        HStack(spacing: 0) {
            stat(value: "\((session.game.history.count + 1) / 2)", label: "Moves")
            divider
            stat(value: "\(session.trayCount(.white))–\(session.trayCount(.black))", label: "Captures")
            if let time = duration {
                divider
                stat(value: time, label: "Time")
            }
        }
        .padding(.vertical, compact ? 8 : 12)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(theme.ink.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(theme.accent.opacity(0.18), lineWidth: 0.6))
    }

    private func stat(value: String, label: String) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(Typeface.display(compact ? 22 : 28, bold: true))
                .monospacedDigit()
                .foregroundStyle(theme.ink)
            Text(label.uppercased())
                .font(.system(size: compact ? 9 : 10, weight: .semibold))
                .tracking(1.5)
                .foregroundStyle(theme.inkSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle().fill(theme.accent.opacity(0.25)).frame(width: 0.6, height: compact ? 28 : 36)
    }

    private var buttons: some View {
        HStack(spacing: 10) {
            Button(action: dismiss) {
                Text("View Board")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(theme.ink)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(Capsule().fill(theme.ink.opacity(0.07)))
                    .overlay(Capsule().strokeBorder(theme.accent.opacity(0.3), lineWidth: 0.6))
            }
            .buttonStyle(PressScaleStyle())
            Button(action: playAgain) {
                Text("Rematch")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color(hex: 0x2A1D0A))
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(
                        Capsule().fill(LinearGradient(colors: [Color(hex: 0xF5E2AC), Color(hex: 0xD4AF66), Color(hex: 0xA8803F)],
                                                      startPoint: .top, endPoint: .bottom))
                    )
                    .overlay(Capsule().strokeBorder(Color(hex: 0xFFF3D0).opacity(0.7), lineWidth: 0.75))
                    .shadow(color: Color(hex: 0xD4AF66).opacity(0.4), radius: 10, y: 3)
            }
            .buttonStyle(PressScaleStyle())
        }
    }

    // MARK: Words

    private func headline(for seat: PieceColor) -> String {
        guard let w = result.winner else { return "Honours even" }
        if settings.isAgainstComputer {
            return w == settings.computerColor ? "TABLE wins" : "You win"
        }
        return w == seat ? "Victory" : "Well fought"
    }

    private func subline(for seat: PieceColor) -> String {
        let moves = (session.game.history.count + 1) / 2
        switch result {
        case .checkmate(let w):
            let final = session.game.history.last.map { " with \($0.san)" } ?? ""
            if settings.isAgainstComputer || w == seat { return "Mate in \(moves) moves\(final)" }
            return "\(ResultText.name(w)) mates\(final)"
        case .resignation(let w):
            if settings.isAgainstComputer {
                return w == settings.computerColor ? "You resigned" : "TABLE resigns"
            }
            return w == seat ? "\(ResultText.name(w.opposite)) resigns" : "You resigned"
        case .draw:
            return ResultText.detail(result)
        }
    }

    private func recordNote(for seat: PieceColor) -> String? {
        guard let ending = session.ending else { return nil }
        if let r = ending.record {
            let level = settings.botLevel.title
            var line = "Against \(level): \(r.wins) won · \(r.losses) lost · \(r.draws) drawn"
            if r.streak >= 2 { line += "\n\(r.streak) wins in a row" + (r.streak == r.bestStreak ? " — your best yet" : "") }
            return line
        }
        if let n = ending.together, seat == viewer {
            return n == 1 ? "Your first game at the table" : "Game \(n) played face to face"
        }
        return nil
    }

    private var duration: String? {
        guard let start = session.startedAt, let end = session.endedAt else { return nil }
        let seconds = Int(end.timeIntervalSince(start))
        if seconds >= 3600 { return "\(seconds / 3600)h \(seconds % 3600 / 60)m" }
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
