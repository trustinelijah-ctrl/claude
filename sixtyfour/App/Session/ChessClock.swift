import Foundation
import ChessCore

/// A time control: minutes each, plus seconds added after every move.
enum TimeControl: String, CaseIterable, Identifiable {
    case off, bullet1, blitz3, blitz5, rapid10, rapid15, classical30

    var id: String { rawValue }

    var minutes: Double? {
        switch self {
        case .off: return nil
        case .bullet1: return 1
        case .blitz3: return 3
        case .blitz5: return 5
        case .rapid10: return 10
        case .rapid15: return 15
        case .classical30: return 30
        }
    }

    var increment: Double {
        switch self {
        case .blitz3: return 2
        case .rapid15: return 10
        default: return 0
        }
    }

    var title: String {
        guard let m = minutes else { return "Off" }
        let base = "\(Int(m))"
        return increment > 0 ? "\(base) | \(Int(increment))" : "\(base) min"
    }
}

/// Two clocks, one running at a time. The clock of the side to move starts after White's
/// first move, and stops whenever it is paused (settings open, app in the background).
struct ChessClock: Equatable {
    private(set) var remaining: [PieceColor: Double]
    let increment: Double
    /// Whose clock is counting down, if anyone's.
    private(set) var running: PieceColor?
    /// When the running clock last resumed; nil while paused.
    private(set) var since: Date?

    init(_ control: TimeControl) {
        let seconds = (control.minutes ?? 0) * 60
        remaining = [.white: seconds, .black: seconds]
        increment = control.increment
    }

    func timeLeft(_ color: PieceColor, at now: Date = Date()) -> Double {
        var t = remaining[color] ?? 0
        if running == color, let since { t -= now.timeIntervalSince(since) }
        return max(0, t)
    }

    var isTicking: Bool { running != nil && since != nil }

    /// `mover` has just moved: their time is banked with the increment, and the other clock starts.
    mutating func moved(_ mover: PieceColor, at now: Date = Date()) {
        if running == mover {
            remaining[mover] = timeLeft(mover, at: now) + increment
        }
        running = mover.opposite
        since = now
    }

    mutating func pause(at now: Date = Date()) {
        guard let r = running, since != nil else { return }
        remaining[r] = timeLeft(r, at: now)
        since = nil
    }

    mutating func resume(at now: Date = Date()) {
        guard running != nil, since == nil else { return }
        since = now
    }

    mutating func stop(at now: Date = Date()) {
        pause(at: now)
        running = nil
    }
}
