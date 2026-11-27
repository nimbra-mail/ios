import Foundation
import NimbraCore

/// The sample mail outside the inboxes, as the 06 · Mailboxes and 11 · mailbox frames show
/// it: drafts, sent mail with reminders on it, a label's threads, Done, and blocked
/// senders.
nonisolated extension SampleData {
    /// A sample thread kept in one mailbox other than the inbox.
    struct Filed: Sendable {
        var thread: MailThread
        var mailbox: Mailbox
    }

    static let tap = Person(name: "TAP Air Portugal", email: "booking@flytap.com", tone: .sky)
    static let airbnb = Person(name: "Airbnb", email: "automated@airbnb.com", tone: .rose)

    /// Each account's labels, in Gmail's order (by name) as 15 · Labels lists them.
    static let labels: [Account.ID: [String]] = [
        work.id: ["Product", "Needs reply", "Due Fri", "Design", "Finance", "Travel"],
        personal.id: ["Travel"],
    ]

    /// Each account's blocked senders (12 · Blocked senders).
    static let blocked: [Account.ID: [String]] = [
        work.id: ["hello@dealsdaily.co", "news@growthweekly.io"],
        personal.id: ["kai@brenner.io"],
    ]

    static func filed(now: Date = .now, calendar: Calendar = .current) -> [Filed] {
        let day = calendar.startOfDay(for: now)
        func at(_ days: Int, _ hour: Int, _ minute: Int = 0) -> Date {
            let d = calendar.date(byAdding: .day, value: -days, to: day) ?? day
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: d) ?? d
        }
        func thread(_ account: Account, _ id: String, _ subject: String, _ who: Person?, _ snippet: String, _ date: Date, labels: [String] = []) -> MailThread {
            MailThread(
                id: MailThread.ID(account: account.id, thread: id), subject: subject, sender: who,
                snippet: snippet, date: date, messageCount: 1, labels: labels
            )
        }
        // In Sent and Drafts the row names who it is to, as the engine's rows do.
        return [
            Filed(thread: thread(work, "draft-launch", "Re: Q4 launch plan", mira,
                                 "Looks great, signing off now. One note on slide 14: let’s keep the annual discount at 20%.", at(0, 9, 52)), mailbox: .drafts),
            Filed(thread: thread(work, "draft-audit", "Re: Component audit", jonah,
                                 "Both fixed. The focus ring now follows the accent in dark mode.", at(1, 17, 20)), mailbox: .drafts),
            Filed(thread: thread(work, "draft-holiday", "Holiday plans", nil,
                                 "Thinking about the last week of December, somewhere warm.", at(2, 21, 5)), mailbox: .drafts),
            Filed(thread: thread(work, "sent-launch", "Q4 launch plan", mira,
                                 "You: Signing off now. One note on slide 14 about the annual discount.", at(0, 9, 58)), mailbox: .sent),
            Filed(thread: thread(work, "sent-audit", "Component audit", jonah,
                                 "You: Sending the two dark mode fixes tomorrow morning.", at(0, 8, 55)), mailbox: .sent),
            Filed(thread: thread(work, "sent-offsite", "Lisbon offsite", ana,
                                 "You: Can you book the dinner for eight? I will send the list.", at(1, 18, 10), labels: ["Travel"]), mailbox: .sent),
            Filed(thread: thread(work, "kickoff", "Kickoff notes", elena,
                                 "Notes from Monday are in the doc. Owners next to every item.", at(5, 11)), mailbox: .done),
            Filed(thread: thread(personal, "tap", "Your booking TP1351", tap,
                                 "Lisbon, December 3. Check-in opens 36 hours before you fly.", at(3, 10)), mailbox: .done)
                .labelled("Travel"),
            Filed(thread: thread(personal, "airbnb", "Reservation confirmed", airbnb,
                                 "Alfama loft, December 3 to 6. Your host is Inês.", at(8, 10)), mailbox: .done)
                .labelled("Travel"),
        ]
    }

    /// The reminders on sent mail (11 · Reminders): back if nobody replies by then.
    static func reminders(now: Date = .now, calendar: Calendar = .current) -> [SnoozedThread] {
        let morning = { (days: Int) -> Int64 in
            let d = calendar.date(byAdding: .day, value: days, to: calendar.startOfDay(for: now)) ?? now
            return (calendar.date(bySettingHour: 8, minute: 0, second: 0, of: d) ?? d).milliseconds
        }
        return filed(now: now, calendar: calendar)
            .filter { $0.mailbox == .sent }
            .enumerated()
            .map { index, filed in
                let thread = filed.thread
                return SnoozedThread(
                    threadId: thread.id.thread, accountId: thread.id.account, untilMs: morning(index < 2 ? 1 : 5),
                    onlyIfNoReply: true, subject: thread.subject, sender: thread.sender?.name ?? "", snippet: thread.snippet
                )
            }
    }
}

nonisolated extension SampleData.Filed {
    func labelled(_ name: String) -> Self {
        var filed = self
        filed.thread.labels.append(name)
        return filed
    }
}
