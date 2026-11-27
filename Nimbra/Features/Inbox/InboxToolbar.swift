import SwiftUI

/// The inbox's top bar (02 · Inbox): the account on the left, the title with today's date
/// in the middle (14 · Offline: what waits, in amber), search and more on the right.
struct InboxToolbar: ToolbarContent {
    @Environment(AppModel.self) private var app

    var body: some ToolbarContent {
        @Bindable var app = app
        ToolbarItem(placement: .topBarLeading) {
            Menu {
                Picker(selection: $app.shownAccountID) {
                    ForEach(app.accounts) { account in
                        Text(verbatim: account.email).tag(account.id)
                    }
                } label: {
                    Text("Account")
                }
                Button("Add account") { app.addingAccount = .providers }
                // MARK: Settings
                Button("Settings") { app.showsSettings = true }
            } label: {
                AvatarView(person: app.account?.person ?? Person(name: "", email: ""), size: 36)
            }
            .accessibilityLabel(Text("Accounts"))
        }
        .sharedBackgroundVisibility(.hidden)

        ToolbarItem(placement: .principal) {
            // MARK: Sending: offline, the overline says so and how much waits.
            if let subtitle = app.connectionSubtitle {
                NavTitle(title: Text("Inbox"), subtitle: Text(verbatim: subtitle), subtitleColor: .accentAmber)
            } else {
                NavTitle(title: Text("Inbox"), subtitle: Text(Date.now, format: .dateTime.weekday(.wide).month(.abbreviated).day()))
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button {
                app.isSearching = true
            } label: {
                Label { Text("Search") } icon: { Icon(.search) }
            }
        }
        ToolbarSpacer(.fixed, placement: .topBarTrailing)
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button("Mark all as read") { Task { await app.markAllRead() } }
            } label: {
                Label { Text("More") } icon: { Icon(.more) }
            }
        }
    }
}
