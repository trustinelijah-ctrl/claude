import Foundation
import ChessCore

/// Portable Game Notation, for sharing a game with any chess program.
enum PGN {
    static func text(for saved: SavedGame) -> String {
        let game = saved.game
        let date = saved.date.formatted(.iso8601.year().month().day().dateSeparator(.dash))
            .replacingOccurrences(of: "-", with: ".")
        let human = saved.humanColor
        let white = saved.level == nil ? "White" : (human == .white ? "Player" : "64 (\(saved.level!.title))")
        let black = saved.level == nil ? "Black" : (human == .black ? "Player" : "64 (\(saved.level!.title))")
        var tags = [
            ("Event", saved.level == nil ? "Face to face" : "Against 64"),
            ("Site", "64 for iPad"),
            ("Date", date),
            ("White", white),
            ("Black", black),
            ("Result", resultTag(game.result)),
        ]
        if game.initialPosition.fen != Position.startFEN {
            tags.append(("SetUp", "1"))
            tags.append(("FEN", game.initialPosition.fen))
        }
        var out = tags.map { "[\($0.0) \"\($0.1)\"]" }.joined(separator: "\n") + "\n\n"
        var line = ""
        for (i, played) in game.history.enumerated() {
            let token = (i % 2 == 0 ? "\(i / 2 + 1). " : "") + played.san
            if line.count + token.count > 78 {
                out += line.trimmingCharacters(in: .whitespaces) + "\n"
                line = ""
            }
            line += token + " "
        }
        out += line + resultTag(game.result) + "\n"
        return out
    }

    static func resultTag(_ r: GameResult?) -> String {
        guard let r else { return "*" }
        switch r.winner {
        case .white?: return "1-0"
        case .black?: return "0-1"
        case nil: return "1/2-1/2"
        }
    }
}
