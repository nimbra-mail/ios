import Foundation
import NimbraCore

/// Keeping time: snoozes and send later due while Nimbra is in front, and the work a
/// background refresh does while it is not (there is no push server; iOS decides when a
/// refresh runs, from the earliest time asked for).
extension AppModel {
    /// After every refresh in front: new mail notified, snoozes due brought back, the badge.
    func afterRefresh() async {
        await checkForNewMail(canAsk: true)
        await wakeDueSnoozes()
        await updateBadge()
    }

    /// While Nimbra is in front: brings snoozes back and sends what is due at their time,
    /// looking again at the soonest deadline (at most a minute apart, so a snooze set
    /// meanwhile is not missed). Run it from the scene's `.task`; it ends when cancelled.
    func stayOnTime() async {
        guard phase == .signedIn else { return }
        await loadNotificationSettings()
        await scheduleSnoozeReturns()
        while !Task.isCancelled {
            let deadline = await nextDeadline()
            let wait = min(max(deadline.map { $0.timeIntervalSince(clock()) } ?? 60, 1), 60)
            try? await Task.sleep(for: .seconds(wait))
            guard !Task.isCancelled else { break }
            if let deadline, deadline <= clock() {
                await wakeDueSnoozes()
                await catchUpOutbox()
                await updateBadge()
            }
        }
    }

    /// Going to the background: the badge, the returns and the next refresh asked for.
    func enteredBackground() async {
        await updateBadge()
        await scheduleSnoozeReturns()
        await scheduleBackgroundRefresh()
    }

    /// A background refresh: snoozes due, new mail, the outbox and send later, within
    /// `budget` (iOS gives about 30 seconds), then what changed written and the next one
    /// asked for. Whether the work finished in time.
    @discardableResult
    func runBackgroundRefresh(budget: Duration = BackgroundRefresh.budget) async -> Bool {
        do throws(MailError) { try await openEngine() } catch { return false }
        if accounts.isEmpty { await reloadAccounts() }
        guard !accounts.isEmpty else { return true }
        await loadNotificationSettings()
        let work = Task {
            await wakeDueSnoozes()
            await checkForNewMail(canAsk: false)
            await catchUpOutbox()
        }
        let finished = await Self.finishes(work, within: budget)
        await updateBadge()
        await scheduleSnoozeReturns()
        await flush()
        await scheduleBackgroundRefresh()
        return finished
    }

    /// Asks iOS for the next refresh: at the soonest deadline, no later than the check
    /// interval. Disk.
    func scheduleBackgroundRefresh() async {
        guard !accounts.isEmpty else { return }
        let deadline = await nextDeadline()
        let interval = await engine { $0.checkIntervalSeconds() } ?? 300
        let earliest = BackgroundRefresh.earliest(now: clock(), deadlines: deadline.map { [$0] } ?? [], checkInterval: TimeInterval(interval))
        refreshScheduler.schedule(at: earliest)
    }

    /// The soonest snooze, send later or retry of every account, and the outbox's
    /// (Compose's `outboxDeadline`). Disk.
    func nextDeadline() async -> Date? {
        let ids = accounts.map(\.id)
        let soonest = await engine { engine in
            ids.compactMap { (try? engine.pendingWork(accountId: $0))?.nextDeadlineMs }.min()
        }
        let pending = soonest.flatMap { $0 }.map(Date.init(milliseconds:))
        return [pending, await outboxDeadline()].compactMap(\.self).min()
    }

    /// Whether `work` ends within `budget`. It is not stopped when it does not: engine
    /// calls cannot be interrupted, and what they finish is kept.
    private static func finishes(_ work: Task<Void, Never>, within budget: Duration) async -> Bool {
        let race = Race()
        return await withCheckedContinuation { continuation in
            Task {
                await work.value
                race.finish(true, continuation)
            }
            Task {
                try? await Task.sleep(for: budget)
                race.finish(false, continuation)
            }
        }
    }
}

/// The first of two answers wins.
private final class Race {
    private var done = false

    func finish(_ value: Bool, _ continuation: CheckedContinuation<Bool, Never>) {
        guard !done else { return }
        done = true
        continuation.resume(returning: value)
    }
}
