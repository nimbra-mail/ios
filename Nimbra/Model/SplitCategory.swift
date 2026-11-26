import SwiftUI

/// Split Inbox: where a thread lands in the inbox.
nonisolated enum SplitCategory: String, CaseIterable, Identifiable {
    case important, team, calendar, newsletters, other

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .important: "Important"
        case .team: "Team"
        case .calendar: "Calendar"
        case .newsletters: "Newsletters"
        case .other: "Other"
        }
    }

    var icon: NimbraIcon {
        switch self {
        case .important: .inbox
        case .team: .users
        case .calendar: .calendar
        case .newsletters: .news
        case .other: .zap
        }
    }
}
