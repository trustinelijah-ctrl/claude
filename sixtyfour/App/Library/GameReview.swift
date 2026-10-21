import SwiftUI
import ChessCore

/// A finished game checked move by move by the engine: how the balance moved, which moves
/// lost ground, and what would have been better.
struct GameReview: Equatable {
    enum Grade: Equatable {
        case best, good, inaccuracy, mistake, blunder

        var mark: String {
            switch self {
            case .best, .good: return ""
            case .inaccuracy: return "?!"
            case .mistake: return "?"
            case .blunder: return "??"
            }
        }

        var word: String {
            switch self {
            case .best: return "The best move"
            case .good: return "A good move"
            case .inaccuracy: return "An inaccuracy"
            case .mistake: return "A mistake"
            case .blunder: return "A blunder"
            }
        }

        var color: Color {
            switch self {
            case .best, .good: return Color(hex: 0x9CC27A)
            case .inaccuracy: return Color(hex: 0xE5C25A)
            case .mistake: return Color(hex: 0xE58A3A)
            case .blunder: return Color(hex: 0xD9483B)
            }
        }
    }

    struct MoveReview: Equatable {
        let grade: Grade
        /// The engine's choice in the position before the move, when it differs.
        let better: Move?
        let betterSAN: String?
    }

    /// The balance after each position, in pawns from White's side, clamped to ±10.
    let balance: [Double]
    let moves: [MoveReview]
    let accuracy: [PieceColor: Int]

    /// Runs the review; about a tenth of a second per position, off the main thread.
    static func run(_ game: ChessGame, progress: @escaping @MainActor (Double) -> Void) async -> GameReview {
        let positions = game.positions
        let history = game.history
        var white: [Int] = []
        var best: [Move?] = []
        for (i, p) in positions.enumerated() {
            let e = await Task.detached(priority: .userInitiated) {
                Engine.evaluate(p, history: Array(positions[..<i]), seconds: 0.12)
            }.value
            let pov = p.sideToMove == .white ? e.score : -e.score
            white.append(max(-1000, min(1000, pov)))
            best.append(e.best)
            await progress(Double(i + 1) / Double(positions.count))
        }

        var reviews: [MoveReview] = []
        var accuracySum: [PieceColor: Double] = [.white: 0, .black: 0]
        var counts: [PieceColor: Int] = [.white: 0, .black: 0]
        for (i, played) in history.enumerated() {
            let mover = positions[i].sideToMove
            let sign = mover == .white ? 1 : -1
            let before = white[i] * sign, after = white[i + 1] * sign
            let loss = max(0, before - after)
            let isBest = best[i] == played.move
            let grade: Grade = isBest ? .best
                : loss >= 300 ? .blunder : loss >= 150 ? .mistake : loss >= 70 ? .inaccuracy : .good
            let better = isBest || grade == .good ? nil : best[i]
            reviews.append(MoveReview(grade: grade, better: better, betterSAN: better.map { positions[i].san(for: $0) }))
            // Accuracy from the drop in winning chances, as most chess sites estimate it.
            let drop = max(0, winChance(before) - winChance(after))
            accuracySum[mover, default: 0] += max(0, min(100, 103.17 * exp(-0.04354 * drop) - 3.17))
            counts[mover, default: 0] += 1
        }
        var accuracy: [PieceColor: Int] = [:]
        for c in [PieceColor.white, .black] where counts[c, default: 0] > 0 {
            accuracy[c] = Int((accuracySum[c, default: 0] / Double(counts[c, default: 1])).rounded())
        }
        return GameReview(balance: white.map { Double($0) / 100 }, moves: reviews, accuracy: accuracy)
    }

    private static func winChance(_ cp: Int) -> Double {
        50 + 50 * (2 / (1 + exp(-0.00368208 * Double(cp))) - 1)
    }
}

/// The balance of the game drawn as a filled line: above the middle, White is better.
struct BalanceGraph: View {
    let balance: [Double]
    let moves: [GameReview.MoveReview]
    let index: Int
    let theme: BoardTheme
    var select: (Int) -> Void = { _ in }

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width, h = proxy.size.height
            let n = max(balance.count - 1, 1)
            let x = { (i: Int) in CGFloat(i) / CGFloat(n) * w }
            let y = { (v: Double) in h / 2 - CGFloat(max(-6, min(6, v)) / 6) * (h / 2 - 2) }
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.black.opacity(0.35))
                Path { p in
                    p.move(to: CGPoint(x: 0, y: h))
                    for (i, v) in balance.enumerated() { p.addLine(to: CGPoint(x: x(i), y: y(v))) }
                    p.addLine(to: CGPoint(x: w, y: h))
                    p.closeSubpath()
                }
                .fill(Brand.cream.opacity(0.85))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                Rectangle().fill(theme.accent.opacity(0.5)).frame(height: 0.5).offset(y: h / 2)
                // Marks where moves lost ground.
                ForEach(Array(moves.enumerated()), id: \.offset) { i, m in
                    if m.grade == .mistake || m.grade == .blunder {
                        Circle().fill(m.grade.color)
                            .frame(width: 6, height: 6)
                            .position(x: x(i + 1), y: y(balance[i + 1]))
                    }
                }
                Rectangle().fill(theme.accent).frame(width: 2, height: h).offset(x: x(index) - 1)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                select(Int((v.location.x / max(w, 1) * CGFloat(n)).rounded()))
            })
        }
        .accessibilityElement()
        .accessibilityLabel("Balance of the game")
    }
}
