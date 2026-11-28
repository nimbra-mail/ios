import Foundation
import NimbraCore

/// Settings › Privacy: clearing the mail kept on this iPhone.
extension AppModel {
    /// Clears what every account keeps on this iPhone, as the Mac's Privacy does: the
    /// lists and threads, the snoozes and reminders kept here, what waits for the
    /// connection, the blocked senders and the learnt addresses. The server's mail, the
    /// sign-ins and the settings stay. What the app shows of them goes too, and the inbox
    /// downloads again.
    func clearKeptMail() async {
        guard !isClearingKeptMail else { return }
        isClearingKeptMail = true
        defer { isClearingKeptMail = false }
        await engine { $0.clearKeptMail() }
        listings = [:]
        opened = [:]
        snoozedThreads = [:]
        snoozes = [:]
        blockedSenders = [:]
        waitingMessages = [:]
        queuedChanges = [:]
        unreadable = []
        remoteImages = [:]
        contactsLearnt = []
        accountPhotos = [:]
        everyPerAccount = [:]
        await showInbox()
    }
}
