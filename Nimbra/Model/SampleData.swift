import Foundation

/// The mail the previews, the tests and the demo launch (`-SignedIn YES`) show: the same
/// threads as the Figma frames and the desktop app's sample mode. `SampleEngine` serves
/// it as the engine would. Never shown to someone who signed in.
nonisolated enum SampleData {
    static let me = Person(name: "Luan Gjokaj", email: "luan@riangle.com", tone: .graphite)
    static let mira = Person(name: "Mira Kovač", email: "mira@northwind.studio", tone: .violet)
    static let jonah = Person(name: "Jonah Reyes", email: "jonah@northwind.studio", tone: .mint)
    static let ana = Person(name: "Ana Petrović", email: "ana@northwind.studio", tone: .amber)
    static let stripe = Person(name: "Stripe", email: "payouts@stripe.com", tone: .graphite)
    static let linear = Person(name: "Linear", email: "notifications@linear.app", tone: .sky)
    static let elena = Person(name: "Elena Brooks", email: "elena@northwind.studio", tone: .rose)

    /// A Gmail account (with the split inbox) and one with its own servers.
    static let work = Account(id: "sample-work", email: "luan@riangle.com", kind: .gmail, isDefault: true)
    static let personal = Account(id: "sample-personal", email: "luan@example.com", kind: .imap)
    static let accounts = [work, personal]

    /// A sample thread, and where it sits: its account's Gmail category (none for an
    /// account with its own servers).
    struct Item: Sendable {
        var thread: MailThread
        var category: SplitCategory?
    }

    /// Times are today's (9:41 and earlier) or this week's, from `now`.
    static func mail(now: Date = .now, calendar: Calendar = .current) -> [Item] {
        let day = calendar.startOfDay(for: now)
        func today(_ hour: Int, _ minute: Int) -> Date {
            calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
        }
        func daysAgo(_ days: Int, _ hour: Int = 10) -> Date {
            let d = calendar.date(byAdding: .day, value: -days, to: day) ?? day
            return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: d) ?? d
        }
        func id(_ account: Account, _ thread: String) -> MailThread.ID {
            MailThread.ID(account: account.id, thread: thread)
        }
        return [
            Item(thread: MailThread(
                id: id(work, "launch"),
                subject: "Q4 launch plan, final review",
                messages: [
                    Message(from: mira, to: [me, jonah], date: daysAgo(2), body: "First pass of the deck. Timeline still says Nov 28, fixing now."),
                    Message(from: jonah, to: [mira, me], date: daysAgo(1), body: "Numbers look right to me. Looping Luan in for final sign-off."),
                    Message(
                        from: mira, to: [me, jonah], date: today(9, 41),
                        body: "Hi Luan,\n\nFinal deck is attached with the updated timeline. We pushed the public launch to December 9, so the new onboarding flow gets one more round of testing.\n\nTwo things before Friday: the pricing tiers on slide 14, and a date for the press embargo.",
                        attachments: [Attachment(name: "Q4-Launch-Plan.pdf", kind: "PDF", size: .init(value: 4.2, unit: .megabytes))]
                    ),
                ],
                labels: ["Needs reply", "Product", "Due Fri"], isUnread: true
            ), category: .primary),
            Item(thread: MailThread(
                id: id(work, "payout"),
                subject: "November payout",
                messages: [Message(from: stripe, to: [me], date: today(9, 12), body: "€24,180.00 arrives Nov 22 in your account ending 4421.")],
                isUnread: true
            ), category: .updates),
            Item(thread: MailThread(
                id: id(work, "audit"),
                subject: "Component audit",
                messages: [
                    Message(from: elena, to: [jonah], date: daysAgo(1), body: "Can you look at the menus before the review?"),
                    Message(from: jonah, to: [me], date: today(8, 47), body: "Two edge cases with focus rings in dark mode, and the menu spacing."),
                ],
                isUnread: true
            ), category: .primary),
            Item(thread: MailThread(
                id: id(work, "offsite"),
                subject: "Lisbon offsite",
                messages: [Message(from: ana, to: [me], date: today(7, 38), body: "Flights booked. Everyone lands Thursday afternoon, dinner at eight.")],
                labels: ["Travel"]
            ), category: .primary),
            Item(thread: MailThread(
                id: id(work, "issues"),
                subject: "3 issues assigned",
                messages: [Message(from: linear, to: [me], date: today(7, 2), body: "NIM-214 Command palette fuzzy matching, and two more for this cycle.")]
            ), category: .updates),
            Item(thread: MailThread(
                id: id(personal, "moodboard"),
                subject: "Nimbra moodboard",
                messages: [Message(from: elena, to: [me], date: daysAgo(3), body: "Pulled a few more references for the aurora, see the board.")]
            ), category: nil),
        ]
    }

    /// The sample threads alone.
    static func threads(now: Date = .now) -> [MailThread] {
        mail(now: now).map(\.thread)
    }
}
