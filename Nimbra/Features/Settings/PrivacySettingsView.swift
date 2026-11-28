import SwiftUI

/// 08 · Settings · Privacy: what Nimbra keeps on this iPhone and how, then clearing the
/// mail it keeps here (the system alert asks first, and says what goes with it).
struct PrivacySettingsView: View {
    @Environment(AppModel.self) private var app
    @State private var confirmsClear = false

    var body: some View {
        SettingsScreen(title: Text("Privacy")) {
            SectionHeader("ON THIS IPHONE")
            GroupCard {
                FactRow(
                    icon: .lock, title: Text("Encrypted on this iPhone"),
                    detail: Text("Mail is locked with a key kept only in your Keychain."), divider: false
                )
                FactRow(icon: .key, title: Text("Sign-ins in the Keychain"), detail: Text("Passwords and sign-ins are never written to a file."))
                FactRow(icon: .mail, title: Text("Only what it needs"), detail: Text("Nimbra asks to read, organize and send. Deleting forever asks once."))
                FactRow(icon: .eye, title: Text("Mail is shown safely"), detail: Text("Scripts never run, images wait until allowed, links open in Safari."))
            }

            GroupCard {
                Button { confirmsClear = true } label: {
                    ListRow(Text("Clear mail kept on this iPhone"), icon: .trash, titleColor: .accentRose, iconColor: .accentRose, divider: false)
                }
                .buttonStyle(.plain)
                .disabled(app.isClearingKeptMail)
            }
            .padding(.top, 8)
            GroupFootnote("Your mail stays on the server and downloads again as needed. Snoozes, reminders, blocked senders, address suggestions and messages waiting to send on this iPhone are cleared too. Accounts, signatures and settings are kept.")
        }
        .alert("Clear mail kept on this iPhone?", isPresented: $confirmsClear) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                Task { await app.clearKeptMail() }
            }
        } message: {
            Text("Nimbra deletes its copy of your mail from this iPhone. Your mail stays on the server and downloads again as needed. Snoozes and reminders, blocked senders, address suggestions and messages waiting to send from this iPhone are deleted too.")
        }
    }
}
