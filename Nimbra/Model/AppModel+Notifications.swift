import Foundation
import NimbraCore

/// A thread a tapped notification opens.
nonisolated struct NotifiedThread: Identifiable, Hashable, Sendable {
    let id: MailThread.ID
}

/// Notifications, as the Mac gives them (`notify.rs`, `mailbox.rs`), on iOS's terms:
///
/// - **New mail** from `check_for_changes`: the engine names the first few new threads and
///   counts the rest, and leaves out blocked senders. Shown in front too (as on the Mac),
///   and from the background refresh.
/// - **Snoozes and reminders** come back with an exact local notification scheduled for
///   their time, kept in step with the snoozes; `wake_due` brings the thread back when the
///   app next runs.
/// - **Done** and **Mark as read** on a thread's notification, without opening the app.
/// - **The badge**: the engine's count (0 when the badge is off in Preferences).
///
/// Permission is asked at the first new mail (16 · Ask, then the system's prompt), never
/// at launch. Settings reads `notificationPermission` and the per-account switches
/// (`notifies`, `setNotifies`), and calls `notificationPreferencesChanged()` after it
/// changes Preferences.
extension AppModel {
    // MARK: Permission

    /// Reads again whether iOS lets Nimbra notify, and the per-account switches.
    func loadNotificationSettings() async {
        notificationsMuted = notificationStore.muted
        notificationPermission = await notifier.permission()
    }

    /// "Turn on notifications" (16 · Ask, or Settings): the system's prompt. Allowed, the
    /// badge and the snoozes' returns follow at once.
    func turnOnNotifications() async {
        isAskingForNotifications = false
        notificationStore.asked = true
        _ = await notifier.requestPermission()
        notificationPermission = await notifier.permission()
        await notificationPreferencesChanged()
    }

    /// "Not now": 16 · Ask does not come back by itself; Settings can still turn them on.
    func notNowNotifications() {
        isAskingForNotifications = false
        notificationStore.asked = true
    }

    /// Whether an account's new mail and snoozes notify (its switch in Settings).
    func notifies(_ account: Account.ID) -> Bool {
        !notificationsMuted.contains(account)
    }

    func setNotifies(_ on: Bool, for account: Account.ID) async {
        if on { notificationsMuted.remove(account) } else { notificationsMuted.insert(account) }
        notificationStore.muted = notificationsMuted
        await scheduleSnoozeReturns()
    }

    /// Preferences changed (notifications, their sound, the badge): the badge and the
    /// scheduled returns follow them.
    func notificationPreferencesChanged() async {
        await updateBadge()
        await scheduleSnoozeReturns()
    }

    // MARK: New mail

    /// Asks every account's server what is new since the last look and notifies about it.
    /// `canAsk`: in front, the first new mail brings up 16 · Ask when Nimbra never asked.
    /// Network.
    func checkForNewMail(canAsk: Bool) async {
        guard !isCheckingMail, !accounts.isEmpty else { return }
        isCheckingMail = true
        defer { isCheckingMail = false }
        guard let preferences = await engine(work: { $0.preferences() }) else { return }
        let store = notificationStore
        for account in accounts.map(\.id) {
            let cursor = store.cursor(account)
            guard let result = await engine(for: account, work: { try $0.checkForChanges(accountId: account, cursor: cursor) }) else { continue }
            reached(account)
            store.setCursor(result.cursor, for: account)
            if result.expired, let key = shownInbox(of: account) {
                await refresh(key)
            }
            let notes = MailNotification.newMail(result, account: account, muted: !notifies(account), sound: preferences.notificationSound)
            guard !notes.isEmpty else { continue }
            switch notificationPermission {
            case .allowed:
                for note in notes { await notifier.post(note) }
            case .notAsked where canAsk && !store.asked:
                isAskingForNotifications = true
            default:
                break
            }
        }
    }

    // MARK: Snoozes

    /// Schedules an exact notification for each snooze's return, and takes back those
    /// cancelled, answered or of an account switched off. Disk.
    func scheduleSnoozeReturns() async {
        guard let host else { return }
        let ids = accounts.map(\.id)
        let found = try? await host.call { engine -> (Preferences, [(account: Account.ID, thread: SnoozedThread)]) in
            let all = ids.flatMap { id in ((try? engine.snoozed(accountId: id)) ?? []).map { (account: id, thread: $0) } }
            return (engine.preferences(), all)
        }
        guard let (preferences, snoozed) = found else { return }
        let pending = await notifier.pendingIDs()
        guard preferences.notifications, notificationPermission == .allowed else {
            notifier.withdraw(pending: pending, delivered: [])
            notificationStore.scheduledReturns = []
            return
        }
        let returns = MailNotification.returns(snoozed, now: clock.now(), muted: notificationsMuted, sound: preferences.notificationSound)
        let wanted = Set(returns.map(\.id))
        notifier.withdraw(pending: pending.filter { !wanted.contains($0) }, delivered: [])
        for note in returns { await notifier.post(note) }
        // Those whose time came stay known as shown, until `wake_due` brings them back.
        let stillSnoozed = Set(snoozed.map { MailNotification.id(account: $0.thread.accountId ?? $0.account, thread: $0.thread.threadId) })
        notificationStore.scheduledReturns = wanted.union(notificationStore.scheduledReturns.intersection(stillSnoozed))
    }

    /// Brings back the snoozes due by now, in every account. A return whose exact
    /// notification already showed is not shown again; one that was not scheduled (iOS's
    /// limit, notifications off then) shows now. A reminder that was answered does not
    /// come back, so its notification is taken back. Network.
    func wakeDueSnoozes() async {
        guard let preferences = await engine(work: { $0.preferences() }) else { return }
        var woken: [(account: Account.ID, thread: SnoozedThread)] = []
        var answered: [String] = []
        for account in accounts.map(\.id) {
            let now = clock.now().milliseconds
            let outcome = await engine(for: account) { engine -> ([SnoozedThread], [SnoozedThread], [SnoozedThread]) in
                let due = try engine.snoozed(accountId: account).filter { $0.untilMs <= now }
                let back = try engine.wakeDue(accountId: account)
                let left = try engine.snoozed(accountId: account)
                return (due, back, left)
            }
            guard let (due, back, left) = outcome else { continue }
            woken += back.map { (account: account, thread: $0) }
            let gone = Set(back.map(\.threadId)).union(left.map(\.threadId))
            answered += due.filter { $0.onlyIfNoReply && !gone.contains($0.threadId) }
                .map { MailNotification.id(account: $0.accountId ?? account, thread: $0.threadId) }
            if !back.isEmpty {
                if let key = shownInbox(of: account) { await refresh(key) }
                await loadSnoozed(account)
            }
        }
        if !answered.isEmpty { notifier.withdraw(pending: answered, delivered: answered) }
        guard !woken.isEmpty else { return }
        var scheduled = notificationStore.scheduledReturns
        let canNotify = preferences.notifications && notificationPermission == .allowed
        for item in woken {
            let note = MailNotification.snoozeReturn(item.thread, account: item.account, sound: preferences.notificationSound)
            if scheduled.remove(note.id) == nil, canNotify, notifies(note.account) {
                await notifier.post(note)
            }
        }
        notificationStore.scheduledReturns = scheduled
    }

    // MARK: Badge

    /// The app icon's number from the engine: unread in every inbox, 0 when it is off.
    func updateBadge() async {
        guard notificationPermission == .allowed, let count = await engine(work: { try $0.badgeCount() }) else { return }
        await notifier.setBadge(Int(count))
    }

    // MARK: Answers

    /// Done or Mark as read on a notification, without opening the app (iOS gives it a few
    /// seconds in the background), or a tap that opens its thread. A snooze that is due is
    /// brought back first, so Done leaves it done rather than snoozed.
    func answerNotification(id: String, action: String) async {
        guard let about = MailNotification.parse(id) else { return }
        do throws(MailError) { try await openEngine() } catch { return }
        if accounts.isEmpty { await reloadAccounts() }
        guard let thread = about.thread else { return }
        let threadID = MailThread.ID(account: about.account, thread: thread)
        switch action {
        case SystemNotifier.done, SystemNotifier.markRead:
            let change: ThreadAction = action == SystemNotifier.done ? .done : .markRead
            let outcome = await engine(for: about.account) { engine in
                _ = try? engine.wakeDue(accountId: about.account)
                return try engine.apply(accountId: about.account, threadId: thread, action: change)
            }
            guard outcome != nil else { return }
            if change == .done { remove(threadID) } else { update(threadID) { $0.isUnread = false } }
            notifier.withdraw(pending: [], delivered: [id])
            await updateBadge()
            await flush()
        default:
            await openNotified(threadID)
        }
    }

    /// Opens a thread from its notification: found in what is listed, else the account's
    /// inbox brought up to date first (a snooze that just came back, new mail).
    private func openNotified(_ id: MailThread.ID) async {
        if thread(id) == nil {
            await wakeDueSnoozes()
            if let key = shownInbox(of: id.account) { await show(key) }
        }
        if thread(id) == nil, let rows = await engine(for: id.account, work: { try $0.cachedThreads(accountId: id.account, mailbox: .inbox) }),
           let row = rows.first(where: { $0.id == id.thread }) {
            opened[id] = MailThread(row: row, account: id.account, labelNames: labelNames(id.account))
        }
        guard thread(id) != nil else { return }
        notifiedThread = NotifiedThread(id: id)
    }

    /// The inbox listing of an account, as the Inbox tab lists it.
    private func shownInbox(of account: Account.ID) -> ListingKey? {
        guard accounts.contains(where: { $0.id == account }) else { return nil }
        if account == accountID { return inboxKey }
        return ListingKey(account: account, mailbox: hasSplitInbox(account) ? SplitCategory.primary.mailbox : .inbox)
    }
}
