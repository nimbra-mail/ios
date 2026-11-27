import Accessibility
import SwiftUI

/// Settings › Account's Sign in again for an account with its own servers whose password
/// stopped working: a new password, checked with both servers (`updateImapPassword`), as
/// 10 · IMAP setup asks for it. A refused password keeps the old one and says so here.
struct ImapSignInAgain: View {
    let accountID: Account.ID
    @Environment(AppModel.self) private var app
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @State private var password = ""
    @State private var showsPassword = false
    @State private var isChecking = false
    @State private var refusal: String?
    @FocusState private var isFocused: Bool

    var body: some View {
        SectionHeader("SIGN IN AGAIN")
        GroupCard {
            FieldRow("Password", divider: false) {
                Group {
                    if showsPassword {
                        TextField("Password", text: $password, prompt: Text.fieldPrompt("Required"))
                    } else {
                        SecureField("Password", text: $password, prompt: Text.fieldPrompt("Required"))
                    }
                }
                .textContentType(.password)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($isFocused)
                .submitLabel(.go)
                .onSubmit(submit)
            } accessory: {
                Button {
                    showsPassword.toggle()
                } label: {
                    Icon(.eye)
                        .foregroundStyle(showsPassword ? Color.accentColor : Color.textSecondary)
                        .frame(width: 44, height: 44)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .padding(-12)
                .accessibilityLabel(showsPassword ? Text("Hide password") : Text("Show password"))
            }
        }
        .opacity(isChecking ? 0.5 : 1)
        .disabled(isChecking)

        if let refusal {
            GroupCard {
                NoticeRow(icon: .alert, iconColor: .accentAmber, text: Text(verbatim: refusal))
            }
            .transition(.opacity)
        } else {
            GroupFootnote("The server stopped taking this account’s password. Enter the new one, or an app password. It is kept in the Keychain on this iPhone.")
        }

        PrimaryButton(isChecking ? "Checking…" : "Sign in", action: submit)
            .disabled(isChecking || password.isEmpty)
            .padding(.top, 8)
    }

    private func submit() {
        guard !password.isEmpty, !isChecking else { return }
        isFocused = false
        isChecking = true
        Task {
            let refused = await app.updateImapPassword(accountID, password: password)
            withAnimation(.smooth) { refusal = refused }
            isChecking = false
            guard let refused else {
                password = ""
                return
            }
            AccessibilityNotification.Announcement(refused).post()
            // VoiceOver reads the refusal instead, which moving the focus would cut off.
            if !voiceOver { isFocused = true }
        }
    }
}
