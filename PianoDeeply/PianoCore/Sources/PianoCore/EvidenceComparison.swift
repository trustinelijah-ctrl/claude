import Foundation

/// One logged attempt, reduced to what a comparison needs.
public struct EvidencePoint: Equatable, Sendable {
    public var id: UUID
    public var taskID: UUID
    public var date: Date
    public var phase: AttemptPhase
    public var tempo: Int?
    public var observation: String
    public var nextStep: String
    public var hasRecording: Bool

    public init(id: UUID = UUID(), taskID: UUID, date: Date, phase: AttemptPhase, tempo: Int? = nil,
                observation: String = "", nextStep: String = "", hasRecording: Bool = false) {
        self.id = id
        self.taskID = taskID
        self.date = date
        self.phase = phase
        self.tempo = tempo
        self.observation = observation
        self.nextStep = nextStep
        self.hasRecording = hasRecording
    }
}

/// A like-for-like pair: same task, same phase, different days.
public struct BeforeNow: Equatable, Sendable {
    public var taskID: UUID
    public var phase: AttemptPhase
    public var before: EvidencePoint
    public var now: EvidencePoint
    /// The most recent next step written for this task, in any phase.
    public var next: String?

    /// Only stated when both attempts recorded a tempo. The app never infers
    /// tempo, accuracy, or tone from audio.
    public var tempoChange: Int? {
        guard let a = before.tempo, let b = now.tempo else { return nil }
        return b - a
    }
}

public enum EvidenceComparison {
    /// The most recently active comparable pair, or nil when nothing is
    /// honestly comparable yet. Cold is never compared with after-practice,
    /// tasks are never mixed, and two attempts on the same day don't count as
    /// before/now.
    public static func latestPair(in points: [EvidencePoint], calendar: Calendar = .current) -> BeforeNow? {
        let groups = Dictionary(grouping: points) { GroupKey(taskID: $0.taskID, phase: $0.phase) }
        var best: BeforeNow?
        for (key, group) in groups {
            guard let pair = pair(in: group, calendar: calendar) else { continue }
            let candidate = BeforeNow(taskID: key.taskID, phase: key.phase, before: pair.0, now: pair.1,
                                      next: latestNextStep(for: key.taskID, in: points))
            if let current = best {
                // Prefer the most recent "now"; on a tie prefer cold, the
                // stronger evidence.
                if candidate.now.date > current.now.date
                    || (candidate.now.date == current.now.date && candidate.phase == .cold && current.phase != .cold) {
                    best = candidate
                }
            } else {
                best = candidate
            }
        }
        return best
    }

    /// All comparable pairs for one task, cold first.
    public static func pairs(forTask taskID: UUID, in points: [EvidencePoint], calendar: Calendar = .current) -> [BeforeNow] {
        let next = latestNextStep(for: taskID, in: points)
        return AttemptPhase.allCases.compactMap { phase in
            let group = points.filter { $0.taskID == taskID && $0.phase == phase }
            guard let pair = pair(in: group, calendar: calendar) else { return nil }
            return BeforeNow(taskID: taskID, phase: phase, before: pair.0, now: pair.1, next: next)
        }
    }

    private struct GroupKey: Hashable {
        let taskID: UUID
        let phase: AttemptPhase
    }

    /// Earliest attempt vs latest attempt, if they fall on different days.
    private static func pair(in group: [EvidencePoint], calendar: Calendar) -> (EvidencePoint, EvidencePoint)? {
        let sorted = group.sorted { $0.date < $1.date }
        guard let first = sorted.first, let last = sorted.last,
              !calendar.isDate(first.date, inSameDayAs: last.date) else { return nil }
        return (first, last)
    }

    private static func latestNextStep(for taskID: UUID, in points: [EvidencePoint]) -> String? {
        points
            .filter { $0.taskID == taskID && !$0.nextStep.isBlank }
            .max { $0.date < $1.date }?
            .nextStep.trimmed
    }
}

/// The greeting on Today. A gap is ordinary, so the copy never counts missed
/// days or mentions streaks.
public enum ReturnGreeting {
    public static let longGapDays = 7

    public static func headline(lastPlayed: Date?, now: Date, calendar: Calendar = .current) -> String {
        if let last = lastPlayed,
           let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: last), to: calendar.startOfDay(for: now)).day,
           days >= longGapDays {
            return "Welcome back."
        }
        switch calendar.component(.hour, from: now) {
        case 5..<12: return "Good morning."
        case 12..<18: return "Good afternoon."
        default: return "Good evening."
        }
    }
}
