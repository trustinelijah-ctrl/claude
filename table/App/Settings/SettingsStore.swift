import SwiftUI
import Observation

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

    var theme: BoardTheme { .with(themeID) }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Keys.theme: ThemeID.walnut.rawValue,
            Keys.sound: true,
            Keys.volume: 0.8,
            Keys.coordinates: true,
            Keys.hints: true,
            Keys.facing: PieceFacing.eachPlayer.rawValue,
        ])
        themeID = ThemeID(rawValue: defaults.string(forKey: Keys.theme) ?? "") ?? .walnut
        soundEnabled = defaults.bool(forKey: Keys.sound)
        volume = defaults.double(forKey: Keys.volume)
        showCoordinates = defaults.bool(forKey: Keys.coordinates)
        showMoveHints = defaults.bool(forKey: Keys.hints)
        pieceFacing = PieceFacing(rawValue: defaults.string(forKey: Keys.facing) ?? "") ?? .eachPlayer
    }

    private enum Keys {
        static let theme = "theme"
        static let sound = "soundEnabled"
        static let volume = "volume"
        static let coordinates = "showCoordinates"
        static let hints = "showMoveHints"
        static let facing = "pieceFacing"
    }
}
