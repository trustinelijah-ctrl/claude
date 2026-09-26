import Foundation
import UserNotifications

/// One daily reminder at a time the learner picks. There are no streaks,
/// following the web's rule that missing a day costs nothing.
enum Reminders {
    static let id = "logos.daily"

    static func schedule(hour: Int, minute: Int, lang: Lang) async -> Bool {
        let center = UNUserNotificationCenter.current()
        let ok = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        guard ok else { return false }
        center.removePendingNotificationRequests(withIdentifiers: [id])
        let content = UNMutableNotificationContent()
        content.title = "LOGOS"
        content.body = lang == .de ? "Die heutige Lektion und deine Abrufe dauern etwa zehn Minuten." : "Today's lesson and your recalls take about ten minutes."
        content.sound = .default
        var dc = DateComponents(); dc.hour = hour; dc.minute = minute
        let req = UNNotificationRequest(identifier: id, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: dc, repeats: true))
        return (try? await center.add(req)) != nil
    }

    static func cancel() { UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id]) }
}
