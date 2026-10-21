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

    /// A king tipped onto the board: a soft wooden knock and a single tap.
    func kingFalls() {
        audio.play(.capture, gain: 0.45)
        audio.play(.place, delay: 0.12, gain: 0.25)
        haptics.place(after: 0)
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
            audio.play(.place, delay: landing, gain: 0.95, pan: pan(to))
            haptics.place(after: landing)
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

    func newGame() {
        audio.play(.reset, gain: 0.95)
    }
}
