import Foundation
import Observation
import ChessCore

/// A finished game, kept so it can be replayed.
struct SavedGame: Codable, Identifiable, Equatable {
    let id: UUID
    let date: Date
    /// nil for two people at the table; otherwise the strength 64 played at.
    let level: BotLevel?
    /// The person's colour against 64.
    let humanColor: PieceColor?
    let duration: TimeInterval?
    let game: ChessGame

    static func == (a: SavedGame, b: SavedGame) -> Bool { a.id == b.id }

    var opponentTitle: String {
        guard let level else { return "Face to face" }
        return "Against 64 · \(level.title)"
    }
}

/// Every finished game, newest first, stored in Application Support.
@MainActor
@Observable
final class GameLibrary {
    static let limit = 200

    private(set) var games: [SavedGame] = []
    @ObservationIgnored private let url: URL

    init(fileName: String = "library.json") {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        url = dir.appendingPathComponent(fileName)
        if let data = try? Data(contentsOf: url),
           let saved = try? JSONDecoder().decode([SavedGame].self, from: data) {
            games = saved
        }
    }

    func add(_ game: ChessGame, level: BotLevel?, humanColor: PieceColor?, duration: TimeInterval?) {
        guard !game.history.isEmpty else { return }
        let saved = SavedGame(id: UUID(), date: Date(), level: level, humanColor: humanColor,
                              duration: duration, game: game)
        games.insert(saved, at: 0)
        if games.count > Self.limit { games.removeLast(games.count - Self.limit) }
        persist()
    }

    func remove(_ game: SavedGame) {
        games.removeAll { $0.id == game.id }
        persist()
    }

    private func persist() {
        let snapshot = games
        let url = url
        Task.detached(priority: .utility) {
            guard let data = try? JSONEncoder().encode(snapshot) else { return }
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? data.write(to: url, options: .atomic)
        }
    }
}
