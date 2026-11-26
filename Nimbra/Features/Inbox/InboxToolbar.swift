import SwiftUI

/// The inbox's top bar: the account on the left, search and more on the right.
struct InboxToolbar: ToolbarContent {
    @Environment(AppModel.self) private var app

    var body: some ToolbarContent {
        @Bindable var app = app
        ToolbarItem(placement: .topBarLeading) {
            Menu {
                Picker(selection: $app.accountID) {
                    ForEach(app.accounts) { account in
                        Text(verbatim: account.email).tag(account.id)
                    }
                } label: {
                    Text("Account")
                }
            } label: {
                AvatarView(person: app.account?.person ?? SampleData.me, size: 36)
            }
            .accessibilityLabel(Text("Accounts"))
        }
        .sharedBackgroundVisibility(.hidden)

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
                Button("Mark all as read") { app.markAllRead(app.split) }
            } label: {
                Label { Text("More") } icon: { Icon(.more) }
            }
        }
    }
}
