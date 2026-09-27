import Foundation

public enum SessionStepKind: String, CaseIterable, Codable, Identifiable, Sendable {
    case arrival
    case technique
    case reading
    case focus
    case application
    case ear
    case improvisation
    case closing

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .arrival: "Arrive"
        case .technique: "Technique"
        case .reading: "Easy reading"
        case .focus: "One focused problem"
        case .application: "Back into music"
        case .ear: "Ear"
        case .improvisation: "Play freely"
        case .closing: "Leave a note"
        }
    }

    public var prompt: String {
        switch self {
        case .arrival: "Play anything you like. No goals yet."
        case .technique: "A scale, arpeggio, or pattern, slow and loose."
        case .reading: "Something new and easy. Keep going; don't fix mistakes."
        case .focus: "Pick one thing that doesn't work yet and work on it."
        case .application: "Put what you just fixed back into the piece around it."
        case .ear: "Find a melody or bass line you know, by ear."
        case .improvisation: "Make something up. Nothing to get right."
        case .closing: "One sentence for next time: what's easier, what's next."
        }
    }

    public var symbol: String {
        switch self {
        case .arrival: "hands.and.sparkles"
        case .technique: "hand.raised.fingers.spread"
        case .reading: "music.note.list"
        case .focus: "scope"
        case .application: "music.quarternote.3"
        case .ear: "ear"
        case .improvisation: "sparkles"
        case .closing: "square.and.pencil"
        }
    }
}

public struct PlannedStep: Equatable, Codable, Identifiable, Sendable {
    public var kind: SessionStepKind
    public var minutes: Int
    public var id: SessionStepKind { kind }

    public init(_ kind: SessionStepKind, _ minutes: Int) {
        self.kind = kind
        self.minutes = minutes
    }
}

/// Starting shapes for a session. These are planning templates the user edits,
/// not a prescription: nothing here claims 13 minutes is the right amount.
public enum SessionPlanner {
    public static let presetMinutes = [20, 30, 60, 90]
    public static let minimumMinutes = 5
    public static let maximumMinutes = 240

    public static func template(minutes requested: Int) -> [PlannedStep] {
        let total = min(max(requested, minimumMinutes), maximumMinutes)
        switch total {
        case 20: return [.init(.arrival, 3), .init(.reading, 4), .init(.focus, 8), .init(.application, 4), .init(.closing, 1)]
        case 30: return [.init(.arrival, 4), .init(.reading, 5), .init(.focus, 13), .init(.application, 6), .init(.closing, 2)]
        case 60: return [.init(.arrival, 5), .init(.technique, 8), .init(.reading, 8), .init(.focus, 20), .init(.application, 10), .init(.ear, 6), .init(.closing, 3)]
        case 90: return [.init(.arrival, 6), .init(.technique, 10), .init(.reading, 10), .init(.focus, 25), .init(.application, 15), .init(.ear, 8), .init(.improvisation, 12), .init(.closing, 4)]
        default: return scaled(to: total)
        }
    }

    /// Custom durations borrow the shape of the nearest preset and scale it,
    /// distributing rounding with the largest-remainder method so the steps
    /// always add up to exactly what was asked for.
    static func scaled(to total: Int) -> [PlannedStep] {
        if total < 10 {
            // Too short for five steps to mean anything.
            let focus = total - 2
            return [.init(.arrival, 1), .init(.focus, focus), .init(.closing, 1)]
        }
        let base = presetMinutes.min { abs($0 - total) < abs($1 - total) }!
        let shape = template(minutes: base)
        let baseTotal = Double(shape.reduce(0) { $0 + $1.minutes })
        let exact = shape.map { Double($0.minutes) * Double(total) / baseTotal }
        var minutes = exact.map { max(1, Int($0.rounded(.down))) }
        var remaining = total - minutes.reduce(0, +)
        let byRemainder = exact.indices.sorted {
            (exact[$0] - exact[$0].rounded(.down)) > (exact[$1] - exact[$1].rounded(.down))
        }
        var cursor = 0
        while remaining > 0 {
            minutes[byRemainder[cursor % byRemainder.count]] += 1
            remaining -= 1
            cursor += 1
        }
        // The max(1, …) floor can overshoot on short sessions; take the
        // excess back from the focus step, which is always the largest.
        if remaining < 0, let focus = shape.firstIndex(where: { $0.kind == .focus }) {
            minutes[focus] += remaining
        }
        return zip(shape, minutes).map { PlannedStep($0.kind, $1) }
    }

    // MARK: Storage

    /// Compact text form for persistence: `arrival:4,focus:13,closing:2`.
    public static func encode(_ steps: [PlannedStep]) -> String {
        steps.map { "\($0.kind.rawValue):\($0.minutes)" }.joined(separator: ",")
    }

    /// Unknown or malformed entries are dropped rather than failing the whole
    /// plan, so a session started by a newer build still opens.
    public static func decode(_ text: String) -> [PlannedStep] {
        text.split(separator: ",").compactMap { part in
            let pieces = part.split(separator: ":")
            guard pieces.count == 2,
                  let kind = SessionStepKind(rawValue: String(pieces[0])),
                  let minutes = Int(pieces[1]), minutes > 0 else { return nil }
            return PlannedStep(kind, minutes)
        }
    }
}
