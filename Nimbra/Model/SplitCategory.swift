import NimbraCore
import SwiftUI

/// Split Inbox: Gmail's own inbox categories, as the Mac app shows them. Accounts with
/// their own servers have none: their inbox is one list.
nonisolated enum SplitCategory: CaseIterable, Identifiable, Hashable, Sendable {
    case primary, updates, promotions, social

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .primary: "Primary"
        case .updates: "Updates"
        case .promotions: "Promotions"
        case .social: "Social"
        }
    }

    var icon: NimbraIcon {
        switch self {
        case .primary: .users
        case .updates: .bell
        case .promotions: .tag
        case .social: .news
        }
    }

    /// Gmail's label for the category, whose unread count the chip shows.
    var labelID: String {
        switch self {
        case .primary: "CATEGORY_PERSONAL"
        case .updates: "CATEGORY_UPDATES"
        case .promotions: "CATEGORY_PROMOTIONS"
        case .social: "CATEGORY_SOCIAL"
        }
    }

    /// The engine's mailbox for the category: the inbox threads in it.
    var mailbox: Mailbox {
        switch self {
        case .primary: .split(category: .primary)
        case .updates: .split(category: .updates)
        case .promotions: .split(category: .promotions)
        case .social: .split(category: .social)
        }
    }
}
