import Foundation
@testable import Nimbra

/// A notification center that records: what showed, what waits for its time, the badge,
/// and the permission asked for.
final class FakeNotifier: Notifier {
    var status = NotificationPermission.notAsked
    /// What the system's prompt answers.
    var allows = true
    private(set) var requests = 0
    /// Shown now, in order.
    private(set) var shown: [MailNotification] = []
    /// Scheduled for their time, by id.
    var pending: [String: MailNotification] = [:]
    /// In Notification Center.
    var delivered: Set<String> = []
    private(set) var badge: Int?

    func permission() async -> NotificationPermission { status }

    func requestPermission() async -> Bool {
        requests += 1
        status = allows ? .allowed : .denied
        return allows
    }

    func post(_ notification: MailNotification) async {
        if notification.fireDate == nil {
            pending[notification.id] = nil
            shown.append(notification)
            delivered.insert(notification.id)
        } else {
            pending[notification.id] = notification
        }
    }

    func pendingIDs() async -> [String] { Array(pending.keys) }
    func deliveredIDs() async -> [String] { Array(delivered) }

    func withdraw(pending ids: [String], delivered gone: [String]) {
        for id in ids { pending[id] = nil }
        delivered.subtract(gone)
    }

    func setBadge(_ count: Int) async { badge = count }
}

final class FakeRefreshScheduler: RefreshScheduler {
    private(set) var asked: [Date] = []
    func schedule(at date: Date) { asked.append(date) }
}
