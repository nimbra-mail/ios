import NimbraCore
import SwiftUI

/// 08 · Settings: the accounts, how mail is checked and sent, notifications, blocked
/// senders, appearance and About.
struct SettingsView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Appearance.key) private var appearance = Appearance.system

    var body: some View {
        SettingsScreen(title: Text("Settings")) {
            SectionHeader("ACCOUNTS")
            GroupCard {
                ForEach(Array(app.accounts.enumerated()), id: \.element.id) { index, account in
                    NavigationLink(value: SettingsRoute.account(account.id)) {
                        SettingsAccountRow(account: account, showsDefault: account.isDefault && app.accounts.count > 1, divider: index > 0)
                    }
                    .buttonStyle(.plain)
                }
                Button(action: app.addAccountFromSettings) {
                    ListRow(Text("Add account"), icon: .plus, titleColor: .accentColor, divider: !app.accounts.isEmpty)
                }
                .buttonStyle(.plain)
            }

            SectionHeader("MAIL")
            GroupCard {
                SettingsMenuRow(
                    title: Text("Check for mail"), icon: .reload, divider: false,
                    options: CheckInterval.allCases, selection: app.preference(\.checkEverySeconds, CheckInterval.init, \.rawValue)
                ) { Text($0.label) }
                SettingsMenuRow(
                    title: Text("Undo send"), icon: .undo,
                    options: UndoSendDelay.allCases, selection: app.preference(\.undoSendSeconds, UndoSendDelay.init, \.rawValue)
                ) { Text($0.label) }
                SettingsToggleRow(title: Text("Quote in replies"), icon: .quote, isOn: app.preference(\.quoteReplies))
                NavigationLink(value: SettingsRoute.notifications) {
                    ListRow(Text("Notifications"), icon: .bell) {
                        ListRowValue(app.preferences.notifications ? Text("On") : Text("Off"))
                        ListRowChevron()
                    }
                }
                .buttonStyle(.plain)
                NavigationLink(value: SettingsRoute.blockedSenders) {
                    ListRow(Text("Blocked senders"), icon: .ban) {
                        if blockedCount > 0 { ListRowValue(Text(blockedCount, format: .number)) }
                        ListRowChevron()
                    }
                }
                .buttonStyle(.plain)
            }
            GroupFootnote("Nimbra checks this often while it’s open. When it’s closed, iOS decides when to check.")

            SectionHeader("APP")
            GroupCard {
                NavigationLink(value: SettingsRoute.appearance) {
                    ListRow(Text("Appearance"), icon: .moon, divider: false) {
                        ListRowValue(Text(appearance.label))
                        ListRowChevron()
                    }
                }
                .buttonStyle(.plain)
                NavigationLink(value: SettingsRoute.about) {
                    ListRow(Text("About"), icon: .info) {
                        ListRowValue(Text(verbatim: Bundle.main.version))
                        ListRowChevron()
                    }
                }
                .buttonStyle(.plain)
            }
            GroupFootnote("Mail and sign-ins stay on this iPhone, encrypted.")
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    Label { Text("Close") } icon: { Icon(.x).foregroundStyle(Color.textPrimary) }
                }
            }
        }
    }

    /// Blocked addresses across the accounts (`blockedSenders`, read when Settings opens).
    private var blockedCount: Int {
        app.accounts.reduce(0) { $0 + (app.blockedSenders[$1.id]?.count ?? 0) }
    }
}
