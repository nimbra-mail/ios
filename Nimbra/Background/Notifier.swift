import Foundation
import UserNotifications

/// Whether iOS lets Nimbra notify, as Settings shows it.
nonisolated enum NotificationPermission: Equatable, Sendable {
    /// Never asked: 16 · Ask comes first, at the first new mail.
    case notAsked
    case denied
    case allowed
}

/// What the app asks of the notification center. The app uses `SystemNotifier`; the tests
/// a fake that records what would have shown.
protocol Notifier: AnyObject {
    func permission() async -> NotificationPermission
    /// The system's prompt. Whether it was allowed.
    func requestPermission() async -> Bool
    /// Shows it now, or schedules it for its `fireDate`. Same id: replaces the one before.
    func post(_ notification: MailNotification) async
    /// Ids of the notifications scheduled and not shown yet (the snoozes' returns).
    func pendingIDs() async -> [String]
    /// Ids of the notifications shown and still in Notification Center.
    func deliveredIDs() async -> [String]
    func withdraw(pending: [String], delivered: [String])
    func setBadge(_ count: Int) async
}

/// The notification center, with the thread category's Done and Mark as read.
final class SystemNotifier: Notifier {
    nonisolated static let category = "thread"
    nonisolated static let done = "done"
    nonisolated static let markRead = "read"
    /// Nimbra's chime, the Mac's (Resources/mail.caf).
    private static let sound = UNNotificationSoundName("mail.caf")

    private var center: UNUserNotificationCenter { .current() }

    /// The actions on a thread's notification. They run without opening the app, after
    /// the device is unlocked: they change mail.
    func registerCategories() {
        let done = UNNotificationAction(
            identifier: Self.done, title: String(localized: "Done"), options: [.authenticationRequired],
            icon: UNNotificationActionIcon(templateImageName: "done")
        )
        let read = UNNotificationAction(
            identifier: Self.markRead, title: String(localized: "Mark as read"), options: [.authenticationRequired],
            icon: UNNotificationActionIcon(templateImageName: "mail")
        )
        let thread = UNNotificationCategory(
            identifier: Self.category, actions: [done, read], intentIdentifiers: [],
            hiddenPreviewsBodyPlaceholder: String(localized: "New message"), options: []
        )
        center.setNotificationCategories([thread])
    }

    func permission() async -> NotificationPermission {
        switch await center.notificationSettings().authorizationStatus {
        case .notDetermined: .notAsked
        case .denied: .denied
        default: .allowed
        }
    }

    func requestPermission() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func post(_ notification: MailNotification) async {
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.subtitle = notification.subtitle
        content.body = notification.body
        content.threadIdentifier = notification.group
        if notification.hasActions { content.categoryIdentifier = Self.category }
        if notification.sound { content.sound = UNNotificationSound(named: Self.sound) }
        var trigger: UNNotificationTrigger?
        if let date = notification.fireDate {
            let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
            trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
        }
        let request = UNNotificationRequest(identifier: notification.id, content: content, trigger: trigger)
        try? await center.add(request)
    }

    func pendingIDs() async -> [String] {
        await center.pendingNotificationRequests().map(\.identifier)
    }

    func deliveredIDs() async -> [String] {
        await center.deliveredNotifications().map(\.request.identifier)
    }

    func withdraw(pending: [String], delivered: [String]) {
        if !pending.isEmpty { center.removePendingNotificationRequests(withIdentifiers: pending) }
        if !delivered.isEmpty { center.removeDeliveredNotifications(withIdentifiers: delivered) }
    }

    func setBadge(_ count: Int) async {
        try? await center.setBadgeCount(count)
    }
}
