import SwiftUI

/// 08 · Settings · Notifications: whether new mail notifies, with a sound, the badge, and
/// which accounts notify. What is notified is Notifications' own work; this screen keeps
/// the switches (the engine's preferences, and `quietAccounts` for each account).
struct NotificationSettingsView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        SettingsScreen(title: Text("Notifications")) {
            GroupCard {
                SettingsToggleRow(title: Text("Notify me about new mail"), icon: .bell, divider: false, isOn: app.preference(\.notifications))
                SettingsToggleRow(title: Text("Play a sound"), icon: .bell, isOn: app.preference(\.notificationSound))
                    .disabled(!app.preferences.notifications)
                SettingsToggleRow(title: Text("Badge app icon"), icon: .inbox, isOn: app.preference(\.badge))
            }
            GroupFootnote("One for each new conversation in your inboxes, with the sender and subject. Blocked senders never notify.")

            SectionHeader("FROM")
            GroupCard {
                ForEach(Array(app.accounts.enumerated()), id: \.element.id) { index, account in
                    SettingsToggleRow(
                        title: Text(verbatim: account.name), icon: .mail, divider: index > 0,
                        isOn: Binding { app.notifies(account.id) } set: { app.setNotifies(account.id, $0) }
                    )
                }
            }
            .disabled(!app.preferences.notifications)
            GroupFootnote("Press a notification to mark it done or read without opening Nimbra.")
        }
    }
}
