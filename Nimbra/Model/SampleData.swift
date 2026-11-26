import Foundation

/// The mail the screens show until accounts sign in: the same threads as the
/// Figma frames and the desktop app's sample mode.
nonisolated enum SampleData {
    static let me = Person(name: "Luan Gjokaj", email: "luan@riangle.com", tone: .graphite)
    static let mira = Person(name: "Mira Kovač", email: "mira@northwind.studio", tone: .violet)
    static let jonah = Person(name: "Jonah Reyes", email: "jonah@northwind.studio", tone: .mint)
    static let ana = Person(name: "Ana Petrović", email: "ana@northwind.studio", tone: .amber)
    static let stripe = Person(name: "Stripe", email: "payouts@stripe.com", tone: .graphite)
    static let linear = Person(name: "Linear", email: "notifications@linear.app", tone: .sky)
    static let elena = Person(name: "Elena Brooks", email: "elena@northwind.studio", tone: .rose)

    static let accounts = [
        Account(name: "Riangle", owner: "Luan Gjokaj", email: "luan@riangle.com", tone: .violet),
        Account(name: "Personal", owner: "Luan Gjokaj", email: "luan@example.com", tone: .mint),
    ]

    /// Times are today's (9:41 and earlier) or this week's, from `now`.
    static func threads(now: Date = .now, calendar: Calendar = .current) -> [MailThread] {
        let day = calendar.startOfDay(for: now)
        func today(_ hour: Int, _ minute: Int) -> Date {
            calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
        }
        func daysAgo(_ days: Int, _ hour: Int = 10) -> Date {
            let d = calendar.date(byAdding: .day, value: -days, to: day) ?? day
            return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: d) ?? d
        }
        return [
            MailThread(
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
                category: .important, labels: ["Needs reply", "Product", "Due Fri"], isUnread: true
            ),
            MailThread(
                subject: "November payout",
                messages: [Message(from: stripe, to: [me], date: today(9, 12), body: "€24,180.00 arrives Nov 22 in your account ending 4421.")],
                category: .important, isUnread: true
            ),
            MailThread(
                subject: "Component audit",
                messages: [
                    Message(from: elena, to: [jonah], date: daysAgo(1), body: "Can you look at the menus before the review?"),
                    Message(from: jonah, to: [me], date: today(8, 47), body: "Two edge cases with focus rings in dark mode, and the menu spacing."),
                ],
                category: .important, isUnread: true
            ),
            MailThread(
                subject: "Lisbon offsite",
                messages: [Message(from: ana, to: [me], date: today(7, 38), body: "Flights booked. Everyone lands Thursday afternoon, dinner at eight.")],
                category: .important, labels: ["Travel"]
            ),
            MailThread(
                subject: "3 issues assigned",
                messages: [Message(from: linear, to: [me], date: today(7, 2), body: "NIM-214 Command palette fuzzy matching, and two more for this cycle.")],
                category: .important
            ),
            MailThread(
                subject: "Nimbra moodboard",
                messages: [Message(from: elena, to: [me], date: daysAgo(3), body: "Pulled a few more references for the aurora, see the board.")],
                category: .team
            ),
        ]
    }
}
