import Foundation

/// The quick times a thread can be snoozed until.
nonisolated enum SnoozeOption: CaseIterable, Identifiable {
    case laterToday, tomorrow, thisWeekend, nextWeek

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .laterToday: "Later today"
        case .tomorrow: "Tomorrow"
        case .thisWeekend: "This weekend"
        case .nextWeek: "Next week"
        }
    }

    var icon: NimbraIcon {
        switch self {
        case .laterToday: .clock
        case .tomorrow: .sun
        case .thisWeekend: .calendar
        case .nextWeek: .next
        }
    }

    /// When the thread comes back, from `now`: 6 PM today (or in three hours,
    /// when that is past), 8 AM tomorrow, 9 AM on Saturday, 8 AM on Monday.
    func date(from now: Date, calendar: Calendar = .current) -> Date {
        let day = calendar.startOfDay(for: now)
        func at(_ hour: Int, daysAhead: Int) -> Date {
            let d = calendar.date(byAdding: .day, value: daysAhead, to: day) ?? day
            return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: d) ?? d
        }
        func next(weekday: Int, hour: Int) -> Date {
            let today = calendar.component(.weekday, from: now)
            var ahead = (weekday - today + 7) % 7
            if ahead == 0 { ahead = 7 }
            return at(hour, daysAhead: ahead)
        }
        switch self {
        case .laterToday:
            let evening = at(18, daysAhead: 0)
            return evening > now.addingTimeInterval(3600) ? evening : now.addingTimeInterval(3 * 3600)
        case .tomorrow: return at(8, daysAhead: 1)
        case .thisWeekend: return next(weekday: 7, hour: 9)
        case .nextWeek: return next(weekday: 2, hour: 8)
        }
    }
}
