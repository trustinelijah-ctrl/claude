import Foundation
import UserNotifications

/// One quiet daily nudge, at a time the learner picks. No streaks, no guilt:
/// the web's rule is that nothing is lost by missing a day.
enum Reminders {
    static let id = "logos.daily"

    static func schedule(hour: Int, minute: Int, lang: Lang) async -> Bool {
        let center = UNUserNotificationCenter.current()
        let ok = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        guard ok else { return false }
        center.removePendingNotificationRequests(withIdentifiers: [id])
        let content = UNMutableNotificationContent()
        content.title = "LOGOS"
        content.body = lang == .de ? "Ein Gedanke, ein Satz, ein Abruf. Etwa zehn Minuten." : "One idea, one sentence, one recall. About ten minutes."
        content.sound = .default
        var dc = DateComponents(); dc.hour = hour; dc.minute = minute
        let req = UNNotificationRequest(identifier: id, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: dc, repeats: true))
        return (try? await center.add(req)) != nil
    }

    static func cancel() { UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id]) }
}
