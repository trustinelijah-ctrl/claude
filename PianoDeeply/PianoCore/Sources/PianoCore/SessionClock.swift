import Foundation

/// A pausable practice timer stored as two plain values, so it survives
/// navigation, backgrounding, and the app being killed: nothing ticks in
/// memory. Elapsed time is always computed from the wall clock.
public struct SessionClock: Equatable, Codable, Sendable {
    /// Seconds banked from earlier running stretches.
    public private(set) var accumulated: TimeInterval
    /// When the current running stretch began; `nil` while paused.
    public private(set) var runningSince: Date?

    public init(accumulated: TimeInterval = 0, runningSince: Date? = nil) {
        self.accumulated = max(0, accumulated)
        self.runningSince = runningSince
    }

    public static func started(at date: Date) -> SessionClock {
        SessionClock(accumulated: 0, runningSince: date)
    }

    public var isRunning: Bool { runningSince != nil }

    public func elapsed(at now: Date) -> TimeInterval {
        guard let since = runningSince else { return accumulated }
        // If the device clock moved backwards, don't subtract time.
        return accumulated + max(0, now.timeIntervalSince(since))
    }

    public mutating func pause(at now: Date) {
        guard runningSince != nil else { return }
        accumulated = elapsed(at: now)
        runningSince = nil
    }

    public mutating func resume(at now: Date) {
        guard runningSince == nil else { return }
        runningSince = now
    }

    /// `12:04`, or `1:02:09` past an hour. Monospaced digits are the view's job.
    public static func format(_ interval: TimeInterval) -> String {
        let seconds = Int(max(0, interval))
        let h = seconds / 3600, m = (seconds % 3600) / 60, s = seconds % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }

    /// Which planned step the elapsed time falls in. Purely advisory: the user
    /// moves between steps themselves, and this only drives a gentle hint.
    public static func stepIndex(for elapsed: TimeInterval, in steps: [PlannedStep]) -> Int? {
        guard !steps.isEmpty else { return nil }
        var boundary: TimeInterval = 0
        for (index, step) in steps.enumerated() {
            boundary += TimeInterval(step.minutes * 60)
            if elapsed < boundary { return index }
        }
        return steps.count - 1
    }
}

/// Retest choices. Due dates land at the start of a day so "tomorrow" means
/// tomorrow morning, not exactly 24 hours after you happened to log it.
public enum RetestInterval: Int, CaseIterable, Identifiable, Sendable {
    case tomorrow = 1
    case threeDays = 3
    case oneWeek = 7
    case fourWeeks = 28

    public var id: Int { rawValue }

    public var label: String {
        switch self {
        case .tomorrow: "Tomorrow"
        case .threeDays: "In 3 days"
        case .oneWeek: "In a week"
        case .fourWeeks: "In 4 weeks"
        }
    }

    public func dueDate(from date: Date, calendar: Calendar = .current) -> Date {
        let start = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: rawValue, to: start) ?? start.addingTimeInterval(TimeInterval(rawValue) * 86_400)
    }
}
