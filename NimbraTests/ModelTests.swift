import Foundation
import Testing
@testable import Nimbra

struct ModelTests {
    @Test(arguments: [
        ("Mira Kovač", "MK"),
        ("Stripe", "S"),
        ("Ana María Petrović", "AP"),
    ])
    func initials(name: String, expected: String) {
        #expect(Person(name: name, email: "a@b.c").initials == expected)
    }

    @Test func initialsFallBackToTheAddress() {
        #expect(Person(name: "", email: "zoe@example.com").initials == "Z")
    }

    @Test func toneIsStableForAName() {
        #expect(Tone.for("Mira Kovač") == Tone.for("Mira Kovač"))
    }

    @Test func replyAndForwardPrefixOnce() {
        let thread = SampleData.threads()[0]
        #expect(ComposeDraft.reply(to: thread).subject == "Re: Q4 launch plan, final review")
        #expect(ComposeDraft.reply(to: thread).to == ["mira@northwind.studio"])
        var answered = thread
        answered.subject = "Re: Plans"
        #expect(ComposeDraft.reply(to: answered).subject == "Re: Plans")
        #expect(ComposeDraft.forward(thread).subject == "Fwd: Q4 launch plan, final review")
    }

    /// Thursday 26 November 2026, 10:00, in a fixed time zone.
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }

    private func date(_ day: Int, _ hour: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour))!
    }

    @Test func snoozeTimes() {
        let now = date(26, 10)
        #expect(SnoozeOption.laterToday.date(from: now, calendar: calendar) == date(26, 18))
        #expect(SnoozeOption.tomorrow.date(from: now, calendar: calendar) == date(27, 8))
        #expect(SnoozeOption.thisWeekend.date(from: now, calendar: calendar) == date(28, 9))
        #expect(SnoozeOption.nextWeek.date(from: now, calendar: calendar) == date(30, 8))
    }

    @Test func laterTodayLateInTheDayIsThreeHoursOn() {
        let now = date(26, 17)
        #expect(SnoozeOption.laterToday.date(from: now, calendar: calendar) == now.addingTimeInterval(3 * 3600))
    }
}
