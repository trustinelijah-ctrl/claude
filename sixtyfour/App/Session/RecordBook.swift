import Foundation
import ChessCore

/// A running score against one opponent: shown on the result card, so every game counts
/// toward something.
struct Record: Codable, Equatable {
    var wins = 0
    var losses = 0
    var draws = 0
    /// Consecutive wins, reset by a loss.
    var streak = 0
    var bestStreak = 0

    var played: Int { wins + losses + draws }
}

/// Results kept on this device: one record per strength of the computer, and a count of games
/// played face to face.
enum RecordBook {
    enum Outcome { case win, loss, draw }

    private static let defaults = UserDefaults.standard

    static func record(against level: BotLevel) -> Record {
        guard let data = defaults.data(forKey: key(level)),
              let r = try? JSONDecoder().decode(Record.self, from: data) else { return Record() }
        return r
    }

    @discardableResult
    static func add(_ outcome: Outcome, against level: BotLevel) -> Record {
        var r = record(against: level)
        switch outcome {
        case .win:
            r.wins += 1
            r.streak += 1
            r.bestStreak = max(r.bestStreak, r.streak)
        case .loss:
            r.losses += 1
            r.streak = 0
        case .draw:
            r.draws += 1
        }
        if let data = try? JSONEncoder().encode(r) { defaults.set(data, forKey: key(level)) }
        return r
    }

    static var gamesTogether: Int { defaults.integer(forKey: "record.together") }

    @discardableResult
    static func addGameTogether() -> Int {
        let n = gamesTogether + 1
        defaults.set(n, forKey: "record.together")
        return n
    }

    private static func key(_ level: BotLevel) -> String { "record.\(level.rawValue)" }
}
