import SwiftUI

// MARK: Settings · hook for Mailboxes
/// Where Settings' Blocked senders row goes. Mailboxes owns the Blocked senders screen:
/// when it lands, this view shows it (replace the body with it). Until then, it says what
/// blocking does.
struct BlockedSendersDestination: View {
    var body: some View {
        SettingsScreen(title: Text("Blocked senders")) {
            GroupFootnote("Mail from blocked senders is put away in Blocked and never notifies.")
        }
    }
}
