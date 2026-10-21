import SwiftUI
import Observation
import ChessCore

enum Opponent: String, CaseIterable, Identifiable {
    /// Two people at the same table.
    case friend
    /// TABLE itself plays the other side.
    case computer
    var id: String { rawValue }
}

enum PieceFacing: String, CaseIterable, Identifiable {
    /// Black's pieces are turned to face the player across the table.
    case eachPlayer
    /// Every piece stands upright for the player on White's side.
    case white
    var id: String { rawValue }
}

/// User preferences, persisted to UserDefaults.
@MainActor
@Observable
final class SettingsStore {
    private let defaults: UserDefaults

    var themeID: ThemeID { didSet { defaults.set(themeID.rawValue, forKey: Keys.theme) } }
    var soundEnabled: Bool { didSet { defaults.set(soundEnabled, forKey: Keys.sound) } }
    var volume: Double { didSet { defaults.set(volume, forKey: Keys.volume) } }
    var showCoordinates: Bool { didSet { defaults.set(showCoordinates, forKey: Keys.coordinates) } }
    var showMoveHints: Bool { didSet { defaults.set(showMoveHints, forKey: Keys.hints) } }
    var pieceFacing: PieceFacing { didSet { defaults.set(pieceFacing.rawValue, forKey: Keys.facing) } }
    var opponent: Opponent { didSet { defaults.set(opponent.rawValue, forKey: Keys.opponent) } }
    var botLevel: BotLevel { didSet { defaults.set(botLevel.rawValue, forKey: Keys.botLevel) } }
    /// The side the person plays against the computer.
    var humanColor: PieceColor { didSet { defaults.set(humanColor.rawValue, forKey: Keys.humanColor) } }

    var isAgainstComputer: Bool { opponent == .computer }
    var computerColor: PieceColor? { isAgainstComputer ? humanColor.opposite : nil }
    /// Against the computer the person always sits at the bottom, so the board turns when they play Black.
    var boardFlipped: Bool { isAgainstComputer && humanColor == .black }
    /// Face-to-face, Black's pieces may face across the table; against the computer every
    /// piece stands upright for the one person playing.
    var turnsTopPieces: Bool { !isAgainstComputer && pieceFacing == .eachPlayer }

    var theme: BoardTheme { .with(themeID) }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Keys.theme: ThemeID.salon.rawValue,
            Keys.sound: true,
            Keys.volume: 0.8,
            Keys.coordinates: true,
            Keys.hints: true,
            Keys.facing: PieceFacing.eachPlayer.rawValue,
            Keys.opponent: Opponent.friend.rawValue,
            Keys.botLevel: BotLevel.club.rawValue,
            Keys.humanColor: PieceColor.white.rawValue,
        ])
        themeID = ThemeID(rawValue: defaults.string(forKey: Keys.theme) ?? "") ?? .salon
        soundEnabled = defaults.bool(forKey: Keys.sound)
        volume = defaults.double(forKey: Keys.volume)
        showCoordinates = defaults.bool(forKey: Keys.coordinates)
        showMoveHints = defaults.bool(forKey: Keys.hints)
        pieceFacing = PieceFacing(rawValue: defaults.string(forKey: Keys.facing) ?? "") ?? .eachPlayer
        opponent = Opponent(rawValue: defaults.string(forKey: Keys.opponent) ?? "") ?? .friend
        botLevel = BotLevel(rawValue: defaults.string(forKey: Keys.botLevel) ?? "") ?? .club
        humanColor = PieceColor(rawValue: defaults.string(forKey: Keys.humanColor) ?? "") ?? .white
    }

    private enum Keys {
        static let theme = "theme"
        static let sound = "soundEnabled"
        static let volume = "volume"
        static let coordinates = "showCoordinates"
        static let hints = "showMoveHints"
        static let facing = "pieceFacing"
        static let opponent = "opponent"
        static let botLevel = "botLevel"
        static let humanColor = "humanColor"
    }
}
