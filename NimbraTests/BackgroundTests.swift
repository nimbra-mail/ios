import Foundation
import NimbraCore
import Testing
@testable import Nimbra

/// The background refresh and its scheduling, on a fake clock and a fake engine; and the
/// snooze sheet's times.
@MainActor
struct BackgroundTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    // MARK: Scheduling

    @Test func theNextRefreshIsTheSoonestDeadlineOrTheInterval() {
        let interval: TimeInterval = 900
        // A snooze in five minutes comes before the interval.
        #expect(BackgroundRefresh.earliest(now: now, deadlines: [now.addingTimeInterval(300)], checkInterval: interval) == now.addingTimeInterval(300))
        // Nothing due: the check interval.
        #expect(BackgroundRefresh.earliest(now: now, deadlines: [], checkInterval: interval) == now.addingTimeInterval(900))
        // A deadline after the interval: the interval still comes first.
        #expect(BackgroundRefresh.earliest(now: now, deadlines: [now.addingTimeInterval(7200)], checkInterval: interval) == now.addingTimeInterval(900))
        // Overdue, or a short interval: never sooner than a minute.
        #expect(BackgroundRefresh.earliest(now: now, deadlines: [now.addingTimeInterval(-30)], checkInterval: 10) == now.addingTimeInterval(60))
    }

    @Test func aRefreshWakesChecksWritesAndAsksForTheNext() async {
        let engine = FakeEngine(accounts: [Fixture.gmail])
        engine.state.withLock { state in
            state.deadlines["g1"] = (now.addingTimeInterval(240)).milliseconds
            state.badge = 3
        }
        let app = Fixture.app(engine)
        let notifier = app.notifier as! FakeNotifier
        notifier.status = .allowed
        let scheduler = app.refreshScheduler as! FakeRefreshScheduler
        app.clock = { [now] in now }

        // iOS started the app for it: nothing is open yet.
        let finished = await app.runBackgroundRefresh(budget: .seconds(5))
        #expect(finished)
        let calls = engine.calls
        #expect(calls.contains("wakeDue g1"))
        #expect(calls.contains("check g1 -"))
        #expect(calls.firstIndex(of: "wakeDue g1")! < calls.firstIndex(of: "check g1 -")!)
        #expect(notifier.badge == 3)
        // The fake checks every minute: that comes before the deadline in four minutes.
        #expect(scheduler.asked == [now.addingTimeInterval(60)])
        #expect(!app.isAskingForNotifications)
    }

    @Test func aSlowServerDoesNotOutlastTheBudget() async {
        let engine = FakeEngine(accounts: [Fixture.gmail])
        engine.state.withLock { $0.checkDelay = 2 }
        let app = Fixture.app(engine)
        let scheduler = app.refreshScheduler as! FakeRefreshScheduler
        let started = ContinuousClock.now
        let finished = await app.runBackgroundRefresh(budget: .milliseconds(200))
        #expect(!finished)
        #expect(ContinuousClock.now - started < .seconds(2))
        // The next one is still asked for.
        #expect(scheduler.asked.count == 1)
    }

    // MARK: Snooze times

    @Test func quickTimesAreTheEnginesWithoutTheReminders() {
        let times = [
            SnoozeTime(kind: .laterToday, untilMs: 1, onlyIfNoReply: false),
            SnoozeTime(kind: .tomorrow, untilMs: 2, onlyIfNoReply: false),
            SnoozeTime(kind: .noReplyInThreeDays, untilMs: 3, onlyIfNoReply: true),
        ]
        #expect(SnoozeChoice.quickTimes(times).map(\.kind) == [.laterToday, .tomorrow])
        let live = SnoozeChoice.quickTimes()
        #expect(!live.isEmpty)
        #expect(live.allSatisfy { $0.until > .now })
    }

    @Test func timesReadAsTheSheetShowsThem() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        let locale = Locale(identifier: "en_US")
        // Thursday, November 26, 2026, 9:41 AM.
        let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 26, hour: 9, minute: 41))!
        func at(_ day: Int, _ hour: Int) -> Date {
            calendar.date(from: DateComponents(year: 2026, month: day > 30 ? 12 : 11, day: day > 30 ? day - 30 : day, hour: hour))!
        }
        func hint(_ date: Date) -> String {
            SnoozeTimeText.hint(date, now: now, calendar: calendar, locale: locale).replacingOccurrences(of: "\u{202F}", with: " ")
        }
        #expect(hint(at(26, 18)) == "6:00 PM")
        #expect(hint(at(27, 8)) == "Fri 8:00 AM")
        #expect(hint(at(30, 8)) == "Mon 8:00 AM")
        #expect(hint(at(37, 8)).hasPrefix("Mon, Dec 7"))
    }

    @Test func aTypedTimeAndAPickedDay() {
        #expect(SnoozePick.time("430p") == TimeOfDay(hour: 16, minute: 30))
        #expect(SnoozePick.time("noon") == TimeOfDay(hour: 12, minute: 0))
        #expect(SnoozePick.time("later") == nil)

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let nine = TimeOfDay(hour: 9, minute: 0)
        #expect(SnoozePick.date(day: calendar.date(byAdding: .day, value: -1, to: today)!, time: nine) == nil)
        #expect(SnoozePick.date(day: tomorrow, time: nine) == calendar.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow))

        let morning = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: today)!
        let evening = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: today)!
        #expect(SnoozePick.firstOpenDay(time: nine, now: morning) == today)
        #expect(SnoozePick.firstOpenDay(time: nine, now: evening) == tomorrow)
    }
}
