import Foundation
import UserNotifications

/// Optional practice reminders. One gentle line, never a count of missed days.
enum ReminderScheduler {
    enum Days: String, CaseIterable, Identifiable {
        case everyDay, weekdays, weekends
        var id: String { rawValue }
        var label: String {
            switch self {
            case .everyDay: "Every day"
            case .weekdays: "Weekdays"
            case .weekends: "Weekends"
            }
        }
        /// Calendar weekday numbers (1 = Sunday); nil means every day.
        var weekdays: [Int]? {
            switch self {
            case .everyDay: nil
            case .weekdays: [2, 3, 4, 5, 6]
            case .weekends: [1, 7]
            }
        }
    }

    static let body = "The piano's there whenever you'd like it."
    private static let prefix = "practice-reminder"

    /// Asks for notification permission (only when the user turns reminders
    /// on) and schedules. Returns false if permission was refused.
    static func enable(hour: Int, minute: Int, days: Days) async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else { return false }
        await schedule(hour: hour, minute: minute, days: days)
        return true
    }

    static func schedule(hour: Int, minute: Int, days: Days) async {
        let center = UNUserNotificationCenter.current()
        await cancel()
        let content = UNMutableNotificationContent()
        content.title = "Piano, Deeply"
        content.body = body
        for weekday in days.weekdays ?? [0] {
            var components = DateComponents()
            components.hour = hour
            components.minute = minute
            if weekday > 0 { components.weekday = weekday }
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(identifier: "\(prefix)-\(weekday)", content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    static func cancel() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(prefix) })
    }
}
