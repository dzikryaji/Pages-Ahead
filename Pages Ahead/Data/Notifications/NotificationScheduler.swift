import Foundation
import UserNotifications

struct LocalNotificationScheduler: NotificationScheduling {
    func schedule(session: ReadingPlan) async throws -> Bool {
        let center = UNUserNotificationCenter.current()
        guard try await center.requestAuthorization(options: [.alert, .sound]) else { return false }
        let content = UNMutableNotificationContent()
        content.title = "Time to read"
        content.body = "Your planned reading window is starting now."
        content.sound = .default
        content.userInfo = ["sessionID": session.id.uuidString]
        guard session.start > .now else { return false }
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: session.start)
        let request = UNNotificationRequest(identifier: session.id.uuidString, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
        center.removePendingNotificationRequests(withIdentifiers: [session.id.uuidString])
        try await center.add(request)
        return true
    }
    func cancel(sessionID: UUID) { UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [sessionID.uuidString]) }
}
