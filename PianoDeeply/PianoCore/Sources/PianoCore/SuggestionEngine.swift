import Foundation

/// What the suggestion rules need to know about a practice task.
public struct TaskSnapshot: Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var skillName: String?
    public var skillIsBottleneck: Bool
    public var createdAt: Date
    public var lastAttemptAt: Date?
    public var lastColdAttemptAt: Date?
    /// The next step written on the most recent attempt, if any.
    public var nextStep: String?
    public var isArchived: Bool

    public init(id: UUID = UUID(), title: String, skillName: String? = nil, skillIsBottleneck: Bool = false,
                createdAt: Date, lastAttemptAt: Date? = nil, lastColdAttemptAt: Date? = nil,
                nextStep: String? = nil, isArchived: Bool = false) {
        self.id = id
        self.title = title
        self.skillName = skillName
        self.skillIsBottleneck = skillIsBottleneck
        self.createdAt = createdAt
        self.lastAttemptAt = lastAttemptAt
        self.lastColdAttemptAt = lastColdAttemptAt
        self.nextStep = nextStep
        self.isArchived = isArchived
    }
}

public struct RetestSnapshot: Equatable, Sendable {
    public var id: UUID
    public var taskID: UUID
    public var taskTitle: String
    public var dueDate: Date
    public var scheduledAt: Date
    public var isCompleted: Bool

    public init(id: UUID = UUID(), taskID: UUID, taskTitle: String, dueDate: Date, scheduledAt: Date, isCompleted: Bool = false) {
        self.id = id
        self.taskID = taskID
        self.taskTitle = taskTitle
        self.dueDate = dueDate
        self.scheduledAt = scheduledAt
        self.isCompleted = isCompleted
    }
}

public struct Suggestion: Equatable, Sendable {
    public enum Rule: String, Sendable {
        case retestDue
        case bottleneckTask
        case bottleneckNeedsTask
        case unfinishedNextStep
        case notTriedColdLately
    }

    public var rule: Rule
    public var taskID: UUID?
    public var retestID: UUID?
    public var title: String
    /// Always shown to the user. Every suggestion says why it was made.
    public var reason: String
}

/// Picks one thing to suggest on the Today screen. Plain ordered rules, no
/// model and no learning; `rulesDescription` is shown verbatim in Settings.
public enum SuggestionEngine {
    public static let staleColdDays = 14
    public static let freshNextStepDays = 21

    public static let rulesDescription: [String] = [
        "A cold retest you scheduled is due.",
        "You marked a skill as your bottleneck: the task linked to it you worked on most recently, or a nudge to pick one.",
        "The most recent task where you wrote a next step, within the last \(freshNextStepDays) days.",
        "A task you haven't tried cold in \(staleColdDays) days or more.",
        "Otherwise, nothing. You get the inventory or Just play instead of an invented task.",
    ]

    public static func suggest(tasks: [TaskSnapshot], retests: [RetestSnapshot], bottleneckSkillName: String?,
                               now: Date, calendar: Calendar = .current) -> Suggestion? {
        let active = tasks.filter { !$0.isArchived }
        let activeIDs = Set(active.map(\.id))

        // 1. A retest that is due. The earliest one first; it has waited longest.
        if let due = retests
            .filter({ !$0.isCompleted && $0.dueDate <= now && activeIDs.contains($0.taskID) })
            .min(by: { $0.dueDate < $1.dueDate }) {
            return Suggestion(rule: .retestDue, taskID: due.taskID, retestID: due.id, title: due.taskTitle,
                              reason: "You set up this cold retest \(DayPhrase.since(due.scheduledAt, now: now, calendar: calendar)).")
        }

        // 2. The bottleneck.
        if let skill = bottleneckSkillName {
            let linked = active.filter(\.skillIsBottleneck)
            if let task = linked.max(by: { ($0.lastAttemptAt ?? $0.createdAt) < ($1.lastAttemptAt ?? $1.createdAt) }) {
                return Suggestion(rule: .bottleneckTask, taskID: task.id, retestID: nil, title: task.title,
                                  reason: "Because you marked \(skill.lowercasedFirst) as your bottleneck.")
            }
            return Suggestion(rule: .bottleneckNeedsTask, taskID: nil, retestID: nil, title: skill,
                              reason: "Because you marked \(skill.lowercasedFirst) as your bottleneck. Pick one passage where it shows up.")
        }

        // 3. A next step you left yourself recently.
        let freshCutoff = calendar.date(byAdding: .day, value: -freshNextStepDays, to: now) ?? now
        if let task = active
            .filter({ ($0.nextStep?.isBlank == false) && ($0.lastAttemptAt ?? .distantPast) >= freshCutoff })
            .max(by: { ($0.lastAttemptAt ?? .distantPast) < ($1.lastAttemptAt ?? .distantPast) }),
           let last = task.lastAttemptAt, let next = task.nextStep {
            return Suggestion(rule: .unfinishedNextStep, taskID: task.id, retestID: nil, title: task.title,
                              reason: "You left yourself a next step \(DayPhrase.since(last, now: now, calendar: calendar)): “\(next.trimmed)”")
        }

        // 4. Something you haven't checked cold in a while. Only tasks you have
        // actually worked on count; a task you never touched isn't "stale".
        let staleCutoff = calendar.date(byAdding: .day, value: -staleColdDays, to: now) ?? now
        if let task = active
            .filter({ $0.lastAttemptAt != nil && ($0.lastColdAttemptAt ?? .distantPast) <= staleCutoff })
            .min(by: { ($0.lastColdAttemptAt ?? .distantPast) < ($1.lastColdAttemptAt ?? .distantPast) }) {
            let reason = task.lastColdAttemptAt.map {
                "You haven't tried this cold since \(DayPhrase.since($0, now: now, calendar: calendar))."
            } ?? "You've practised this but haven't tried it cold yet."
            return Suggestion(rule: .notTriedColdLately, taskID: task.id, retestID: nil, title: task.title, reason: reason)
        }

        return nil
    }

    /// The next retest that isn't due yet, for the quiet preview on Today.
    public static func nextUpcomingRetest(_ retests: [RetestSnapshot], now: Date) -> RetestSnapshot? {
        retests.filter { !$0.isCompleted && $0.dueDate > now }.min { $0.dueDate < $1.dueDate }
    }
}

/// Deterministic relative day phrases ("today", "3 days ago", "2 weeks ago").
public enum DayPhrase {
    public static func since(_ date: Date, now: Date, calendar: Calendar = .current) -> String {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day ?? 0
        switch days {
        case ..<1: return "today"
        case 1: return "yesterday"
        case 2..<14: return "\(days) days ago"
        default: return "\(days / 7) weeks ago"
        }
    }

    public static func until(_ date: Date, now: Date, calendar: Calendar = .current) -> String {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)).day ?? 0
        switch days {
        case ..<1: return "today"
        case 1: return "tomorrow"
        case 2..<14: return "in \(days) days"
        default: return "in \(days / 7) weeks"
        }
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    var isBlank: Bool { trimmed.isEmpty }

    /// "Left-hand coordination" reads better mid-sentence as "left-hand
    /// coordination". Leaves acronyms and chord names like "ii–V–I" alone.
    var lowercasedFirst: String {
        guard let first = first, first.isUppercase else { return self }
        let second = dropFirst().first
        if let second, second.isUppercase { return self }
        return first.lowercased() + dropFirst()
    }
}
