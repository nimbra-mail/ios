import Foundation
import NimbraCore

/// A quick time in 05 · Snooze, from the engine's `snooze_times` (the Mac's menu): later
/// today (or in three hours, after 5 PM), tomorrow morning and evening, the weekend, next
/// week. The reminders are not rows: "Only if nobody replies" makes any time one.
nonisolated struct SnoozeChoice: Identifiable, Equatable, Sendable {
    let kind: SnoozeKind
    let until: Date

    var id: Int64 { until.milliseconds }

    /// The quick times from now, soonest first.
    static func quickTimes(_ times: [SnoozeTime] = snoozeTimes()) -> [SnoozeChoice] {
        times.filter { !$0.onlyIfNoReply }.compactMap { time in
            switch time.kind {
            case .noReplyInThreeDays, .noReplyInAWeek: nil
            default: SnoozeChoice(kind: time.kind, until: Date(milliseconds: time.untilMs))
            }
        }
    }

    var title: LocalizedStringResource {
        switch kind {
        case .laterToday: "Later today"
        case .inThreeHours: "In three hours"
        case .tomorrow: "Tomorrow"
        case .tomorrowEvening: "Tomorrow evening"
        case .thisWeekend: "This weekend"
        case .nextWeek: "Next week"
        case .noReplyInThreeDays: "In three days"
        case .noReplyInAWeek: "In a week"
        }
    }

    var icon: NimbraIcon {
        switch kind {
        case .laterToday, .inThreeHours: .clock
        case .tomorrow: .sun
        case .tomorrowEvening: .moon
        case .thisWeekend, .noReplyInThreeDays, .noReplyInAWeek: .calendar
        case .nextWeek: .next
        }
    }
}

/// How a snooze's time reads, as in 05 · Snooze: the time alone today ("6:00 PM"), the
/// weekday within the week ("Fri 8:00 AM"), the date after that ("Mon, Dec 7, 8:00 AM").
nonisolated enum SnoozeTimeText {
    static func hint(_ date: Date, now: Date, calendar: Calendar = .current, locale: Locale = .current) -> String {
        var style = Date.FormatStyle(date: .omitted, time: .shortened, locale: locale, calendar: calendar, timeZone: calendar.timeZone)
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)).day ?? 0
        switch days {
        case 0: break
        case 1...6: style = style.weekday(.abbreviated)
        default: style = style.weekday(.abbreviated).month(.abbreviated).day()
        }
        return date.formatted(style)
    }
}

/// A day picked in the calendar, at a time typed in ("4:30 PM", "16:30", "430p", "noon"),
/// read by the engine as the Mac reads it.
nonisolated enum SnoozePick {
    /// The time typed, or nil when it is not one.
    static func time(_ text: String) -> TimeOfDay? {
        parseTime(text: text)
    }

    /// When that day and time come back in the device's time zone; nil for a time gone by.
    static func date(day: Date, time: TimeOfDay, calendar: Calendar = .current) -> Date? {
        let parts = calendar.dateComponents([.year, .month, .day], from: day)
        guard let year = parts.year, let month = parts.month, let dayOfMonth = parts.day else { return nil }
        return dayTime(year: Int32(year), month: UInt32(month), day: UInt32(dayOfMonth), time: time).map(Date.init(milliseconds:))
    }

    /// The day the calendar starts on: today if the time is still ahead today, else tomorrow.
    static func firstOpenDay(time: TimeOfDay, now: Date, calendar: Calendar = .current) -> Date {
        let today = calendar.startOfDay(for: now)
        if let at = calendar.date(bySettingHour: Int(time.hour), minute: Int(time.minute), second: 0, of: today), at > now {
            return today
        }
        return calendar.date(byAdding: .day, value: 1, to: today) ?? today
    }

    /// "9:00 AM", as the locale writes it.
    static func text(_ time: TimeOfDay, calendar: Calendar = .current) -> String {
        let at = calendar.date(bySettingHour: Int(time.hour), minute: Int(time.minute), second: 0, of: .now) ?? .now
        return at.formatted(date: .omitted, time: .shortened)
    }
}
