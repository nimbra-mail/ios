import UserNotifications

/// Takes the answers to Nimbra's notifications: Done and Mark as read (run in the
/// background, the app not opened), a tap (opens the thread), and shows banners while
/// Nimbra is in front, as the Mac does. Set as the center's delegate at launch, before the
/// app finishes launching, so an answer that starts the app is not lost.
final class NotificationResponder: NSObject, UNUserNotificationCenterDelegate {
    private let app: AppModel
    private let notifier = SystemNotifier()

    init(app: AppModel) {
        self.app = app
    }

    func start() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        notifier.registerCategories()
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse
    ) async {
        let id = response.notification.request.identifier
        let action = response.actionIdentifier
        await app.answerNotification(id: id, action: action)
    }

    /// In front: a snooze coming back brings its thread back now; new mail shows as a
    /// banner, in the list and with its sound.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        let id = notification.request.identifier
        if notification.request.trigger is UNCalendarNotificationTrigger {
            await app.notificationShowed(id)
        }
        return [.banner, .list, .sound]
    }
}

extension AppModel {
    /// A snooze's exact return showed while Nimbra is in front: the thread comes back now.
    func notificationShowed(_ id: String) async {
        guard MailNotification.parse(id) != nil else { return }
        await wakeDueSnoozes()
    }
}
