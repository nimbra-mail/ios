import Foundation
import NimbraCore

/// Staying current while the app is in front: everything at once on launch and on coming
/// back, then again whenever the server says something changed (`ChangeWatch`: IMAP IDLE,
/// Gmail's live updates) or the check interval from Preferences passes. Background
/// refresh is not here yet.
extension AppModel {
    /// Brings every account's inbox and counts up to date, side by side. Network.
    func refreshAll() async {
        guard phase == .signedIn else { return }
        let keys = accounts.map { account in
            account.id == accountID ? inboxKey : ListingKey(account: account.id, mailbox: .inbox)
        }.compactMap(\.self)
        await withDiscardingTaskGroup { group in
            for key in keys {
                group.addTask { await self.refresh(key) }
            }
        }
        if let accountID { await loadSnoozed(accountID) }
        // MARK: Notifications
        await afterRefresh()
    }

    /// Refreshes now, then each time the account shown says it changed or the interval
    /// passes, until the task is cancelled (the app leaves the foreground, another
    /// account is shown). Run it from the scene's `.task`.
    func stayCurrent() async {
        guard phase == .signedIn else { return }
        await refreshAll()
        // One watch for the run: it keeps its connection between waits.
        var watch: (any ChangeWatchProtocol)?
        if let account = accountID {
            watch = await engine(for: account, work: { try $0.changeWatch(accountId: account) })
        }
        while !Task.isCancelled {
            await waitForChange(on: watch)
            guard !Task.isCancelled else { break }
            await refreshAll()
        }
        watch?.cancel()
    }

    /// Waits for the server to say something changed, at most the check interval; without
    /// a watch (offline, or it could not connect), just the interval.
    private func waitForChange(on watch: (any ChangeWatchProtocol)?) async {
        let seconds = await engine { $0.checkIntervalSeconds() } ?? 300
        guard let watch else {
            try? await Task.sleep(for: .seconds(Int(seconds)))
            return
        }
        // The wait blocks an engine thread; cancelling the task ends it within a moment.
        let outcome = await withTaskCancellationHandler {
            await engine { _ in watch.wait(seconds: seconds) }
        } onCancel: {
            watch.cancel()
        }
        if outcome == .cancelled, !Task.isCancelled {
            // The watch ended on its own: wait out the interval instead.
            try? await Task.sleep(for: .seconds(Int(seconds)))
        }
    }

    /// The app went to the background: write what waits to be written, while iOS still
    /// gives the app a few seconds.
    func flush() async {
        await host?.flush()
    }
}
