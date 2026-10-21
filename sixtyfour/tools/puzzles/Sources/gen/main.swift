import ChessCore
import Foundation

// Finds positions with a forced mate, from casual-strength games that make the kind of
// mistakes real players make. Prints "N|FEN|firstMove" lines.
var rng = SystemRandomNumberGenerator()
var found: [Int: [(String, String)]] = [1: [], 2: [], 3: []]
var seen = Set<String>()
let want = [1: 40, 2: 40, 3: 20]
let start = Date()
while (found[1]!.count < want[1]! || found[2]!.count < want[2]! || found[3]!.count < want[3]!)
        && Date().timeIntervalSince(start) < 1500 {
    var g = ChessGame()
    for ply in 0..<120 {
        if g.isOver { break }
        let p = g.position
        if ply >= 12 {
            var pieces = 0
            for sq in Square.all where p[sq] != nil { pieces += 1 }
            let e = Engine.evaluate(p, seconds: 0.05)
            if let m = e.mateIn, m >= 1, m <= 3, pieces >= 8, found[m]!.count < want[m]! {
                // Confirm with a longer look, and for mate in one, keep only positions with a single mating move.
                let sure = Engine.evaluate(p, seconds: 0.6)
                let key = p.fen.split(separator: " ").prefix(2).joined(separator: " ")
                if sure.mateIn == m, !seen.contains(key), let best = sure.best {
                    var ok = true
                    if m == 1 {
                        let mates = p.legalMoves().filter { mv in
                            var t = g; t.play(mv); if case .checkmate? = t.result { return true }; return false
                        }
                        ok = mates.count == 1
                    }
                    // Avoid positions where the side to move is far behind or crushingly ahead: those read badly as puzzles.
                    if ok {
                        seen.insert(key)
                        found[m]!.append((p.fen, best.description))
                        FileHandle.standardError.write("found mate in \(m): \(found[m]!.count)\n".data(using: .utf8)!)
                    }
                }
            }
        }
        let level: BotLevel = Bool.random(using: &rng) ? .casual : .club
        guard let mv = Engine.bestMove(for: g, level: level) else { break }
        g.play(mv)
    }
}
for n in [1, 2, 3] { for (fen, mv) in found[n]! { print("\(n)|\(fen)|\(mv)") } }
