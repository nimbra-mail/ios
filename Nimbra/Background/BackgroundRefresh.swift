import BackgroundTasks
import Foundation

/// Background refresh: iOS runs it when it sees fit, from the earliest time asked for.
/// There is no push server, so this is how new mail notifies, snoozes come back and send
/// later goes out while Nimbra is not in front. Registered in Info.plist
/// (`BGTaskSchedulerPermittedIdentifiers`, `UIBackgroundModes` fetch) and run by the
/// scene's `.backgroundTask(.appRefresh(BackgroundRefresh.identifier))`.
nonisolated enum BackgroundRefresh {
    static let identifier = "com.riangle.nimbra.refresh"

    /// iOS gives a refresh about 30 seconds: the work stops at this, leaving time to write
    /// what it changed.
    static let budget: Duration = .seconds(22)

    /// The earliest a refresh should run: at the soonest deadline the engine knows of (a
    /// snooze, a send later, a retry), and no later than the check interval from now; never
    /// sooner than a minute from now. iOS may run it later still.
    static func earliest(now: Date, deadlines: [Date], checkInterval: TimeInterval) -> Date {
        let soonest = min(deadlines.min() ?? .distantFuture, now.addingTimeInterval(checkInterval))
        return max(soonest, now.addingTimeInterval(60))
    }
}

/// Asks iOS for the next background refresh. The tests use a fake.
protocol RefreshScheduler: AnyObject {
    func schedule(at date: Date)
}

final class SystemRefreshScheduler: RefreshScheduler {
    func schedule(at date: Date) {
        let request = BGAppRefreshTaskRequest(identifier: BackgroundRefresh.identifier)
        request.earliestBeginDate = date
        // One waits at a time: a new request replaces the one before. It fails on the
        // simulator and when Background App Refresh is off; the foreground still works.
        try? BGTaskScheduler.shared.submit(request)
    }
}
