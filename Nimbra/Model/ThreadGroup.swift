import Foundation

/// Threads under an overline in a mailbox's list, as the 11 frames group them: TODAY and
/// EARLIER in an inbox; THIS WEEK, THIS MONTH and EARLIER in the other mailboxes; and by
/// when they come back (TOMORROW, NEXT WEEK…) in Snoozed and Reminders.
nonisolated struct ThreadGroup: Identifiable, Sendable {
    /// How a list groups its threads.
    enum Kind: Sendable {
        /// Today and earlier (an inbox, All inboxes).
        case inbox
        /// This week, this month, earlier.
        case past
        /// By when each comes back: today, tomorrow, this week, next week, later.
        case upcoming
    }

    let title: LocalizedStringResource
    var threads: [MailThread]

    var id: String { title.key }

    /// The threads in order, under their overlines; `date` is when each is placed (its
    /// date, or when it comes back).
    static func group(
        _ threads: [MailThread], as kind: Kind, date: (MailThread) -> Date,
        now: Date = .now, calendar: Calendar = .current
    ) -> [ThreadGroup] {
        var groups: [ThreadGroup] = []
        for thread in threads {
            let title = Self.title(of: date(thread), as: kind, now: now, calendar: calendar)
            if let index = groups.firstIndex(where: { $0.id == title.key }) {
                groups[index].threads.append(thread)
            } else {
                groups.append(ThreadGroup(title: title, threads: [thread]))
            }
        }
        return groups
    }

    private static func title(of date: Date, as kind: Kind, now: Date, calendar: Calendar) -> LocalizedStringResource {
        switch kind {
        case .inbox:
            return calendar.isDate(date, inSameDayAs: now) ? "TODAY" : "EARLIER"
        case .past:
            if calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear) { return "THIS WEEK" }
            if calendar.isDate(date, equalTo: now, toGranularity: .month) { return "THIS MONTH" }
            return "EARLIER"
        case .upcoming:
            if calendar.isDate(date, inSameDayAs: now) { return "TODAY" }
            if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
               calendar.isDate(date, inSameDayAs: tomorrow) { return "TOMORROW" }
            if calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear) { return "THIS WEEK" }
            if let next = calendar.date(byAdding: .weekOfYear, value: 1, to: now),
               calendar.isDate(date, equalTo: next, toGranularity: .weekOfYear) { return "NEXT WEEK" }
            return "LATER"
        }
    }
}
