import Foundation
import ChessCore

/// Turns board events into sound and touch, timed against the animation that shows them.
@MainActor
final class FeedbackCoordinator {
    let audio = AudioManager()
    let haptics = HapticManager()

    func apply(_ settings: SettingsStore) {
        audio.setEnabled(settings.soundEnabled)
        audio.setVolume(settings.volume)
        audio.setAmbience(settings.ambience)
        audio.setAmbienceVolume(settings.ambienceVolume)
        haptics.enabled = settings.hapticsEnabled
    }

    /// Screen-space stereo position of a square. White sits at the bottom, so file a is on the left.
    private func pan(_ square: Square) -> Float {
        Float(square.file - 4) / 3.5 * 0.32 + 0.045
    }

    func pickup(at square: Square) {
        audio.play(.pickup, pan: pan(square))
        haptics.pickup()
    }

    func invalid(at square: Square) {
        audio.play(.invalid, gain: 0.9, pan: pan(square))
    }

    func putBack(at square: Square) {
        audio.play(.place, delay: 0.06, gain: 0.32, pan: pan(square))
    }

    /// A taken piece set down in a tray: lighter than a move.
    func trayLanding() {
        audio.play(.place, gain: 0.32)
    }

    /// A king tipped onto the board. The sound carries the knock, two bounces and a short
    /// roll; `impact` is when the crown meets the board in the animation.
    func kingFalls(impact: TimeInterval) {
        audio.play(.topple, delay: impact, gain: 0.8)
        haptics.capture(after: impact)
        haptics.place(after: impact + 0.105, weight: 0.35)
        haptics.place(after: impact + 0.175, weight: 0.15)
    }

    /// The chess clock's plunger, pressed by the player who just moved.
    func clockPressed(by color: PieceColor, landing: TimeInterval) {
        audio.play(.clockPress, delay: landing + 0.07, gain: 0.8, pan: color == .white ? 0.25 : -0.25)
    }

    /// One tick of the clock in its last seconds.
    func clockTick() {
        audio.play(.clockTick, gain: 0.7)
    }

    /// Pawns are light, rooks, queens and kings heavy; the board answers each differently.
    static func placement(for kind: PieceKind) -> SoundEffect {
        switch kind {
        case .pawn: return .placeLight
        case .rook, .queen, .king: return .placeHeavy
        case .knight, .bishop: return .place
        }
    }

    static func weight(of kind: PieceKind) -> Float {
        switch kind {
        case .pawn: return 0.5
        case .rook, .queen, .king: return 0.9
        case .knight, .bishop: return 0.7
        }
    }

    /// A carried piece crossing into another square: a faint notch, and a tap on iPhone.
    func crossed(_ square: Square) {
        audio.play(.notch, gain: 0.8, pan: pan(square))
        haptics.place(after: 0, weight: 0.22)
    }

    func ui() {
        audio.play(.ui)
    }

    /// - Parameters:
    ///   - landing: seconds until the moving piece lands.
    ///   - rookLanding: for castling, seconds until the rook lands.
    func moveCommitted(_ played: PlayedMove, landing: TimeInterval, rookLanding: TimeInterval?, result: GameResult?) {
        let to = played.move.to
        if played.effect.isCapture {
            audio.play(.capture, delay: landing, pan: pan(to))
            haptics.capture(after: landing)
        } else {
            audio.play(Self.placement(for: played.effect.piece.kind), delay: landing, gain: 0.95, pan: pan(to))
            haptics.place(after: landing, weight: Self.weight(of: played.effect.piece.kind))
        }
        if let rookTo = played.effect.rookTo, let rookLanding {
            audio.play(.place, delay: rookLanding, gain: 0.72, pan: pan(rookTo))
            haptics.place(after: rookLanding)
        }
        if played.effect.promotion != nil {
            audio.play(.promotion, delay: landing + 0.03, gain: 0.9, pan: pan(to) * 0.5)
        }

        let settled = max(landing, rookLanding ?? 0)
        switch result {
        case .checkmate:
            audio.play(.checkmate, delay: settled + 0.16)
            haptics.checkmate(after: settled + 0.16)
        case .draw:
            audio.play(.draw, delay: settled + 0.28, gain: 0.9)
        default:
            if played.givesCheck {
                audio.play(.check, delay: settled + 0.1, gain: 0.85, pan: pan(to) * 0.5)
            }
        }
    }

    func promotionOffered(at square: Square) {
        audio.play(.ui, gain: 0.8, pan: pan(square))
    }

    func undo(landing: TimeInterval, square: Square?) {
        audio.play(.place, delay: landing, gain: 0.55, pan: square.map(pan) ?? 0)
    }

    func gameEndedByChoice() {
        audio.play(.draw, gain: 0.8)
    }

    /// The pieces gathered, then set back down rank by rank: a quick run of small clicks.
    func newGame() {
        audio.play(.reset, gain: 0.95)
        for i in 0..<8 {
            let pan: Float = (i % 2 == 0 ? -0.18 : 0.18)
            audio.play(i % 3 == 0 ? .place : .placeLight, delay: 0.42 + Double(i) * 0.055,
                       gain: 0.3 - Float(i) * 0.02, pan: pan)
        }
    }
}
