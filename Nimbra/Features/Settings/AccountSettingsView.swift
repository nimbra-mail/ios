import AuthenticationServices
import NimbraCore
import SwiftUI

/// 08 · Settings · Account: who it is, whether it is the default, its signatures, signing
/// in again when its sign-in is gone, and removing it from this iPhone.
struct AccountSettingsView: View {
    let accountID: Account.ID
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Environment(\.webAuthenticationSession) private var webAuthenticationSession
    @State private var confirmsRemove = false

    var body: some View {
        if let account = app.accounts.first(where: { $0.id == accountID }) {
            SettingsScreen(title: Text(verbatim: account.name)) {
                profile(account)
                defaultGroup(account)
                signatureGroup(account)
                if app.signedOut.contains(account.id) {
                    if let provider = account.provider {
                        signInAgainGroup(provider)
                    } else if account.kind == .imap {
                        ImapSignInAgain(accountID: account.id)
                    }
                }
                Color.clear.frame(height: 8)
                removeGroup(account)
            }
            .task { await app.loadSignatures(accountID) }
            .alert(Text("Remove \(account.email)?"), isPresented: $confirmsRemove) {
                Button("Cancel", role: .cancel) {}
                Button("Remove", role: .destructive) {
                    Task {
                        if await app.removeAccountInSettings(accountID) { dismiss() }
                    }
                }
            } message: {
                Text("Nimbra signs out of it and deletes its mail from this iPhone. Its mail on the server, and your other accounts, stay as they are.")
            }
        }
    }

    private func profile(_ account: Account) -> some View {
        VStack(spacing: 4) {
            AvatarView(person: account.person, size: 64)
                .padding(.bottom, 6)
            Text(verbatim: account.person.name)
                .nimbraText(.headline)
                .foregroundStyle(Color.textPrimary)
            Text("\(account.email) · \(Text(account.kind.label))")
                .nimbraText(.footnote)
                .foregroundStyle(Color.textTertiary)
        }
        .lineLimit(1)
        .frame(maxWidth: .infinity)
        .padding(.bottom, 10)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func defaultGroup(_ account: Account) -> some View {
        GroupCard {
            SettingsToggleRow(
                title: Text("Default account"), icon: .star, divider: false,
                isOn: Binding {
                    account.isDefault
                } set: { isOn in
                    // The default changes by picking another: this one cannot be turned off.
                    if isOn { Task { await app.makeDefault(account.id) } }
                }
            )
        }
        GroupFootnote("New messages are from this account, and its photo shows in Inbox.")
    }

    @ViewBuilder
    private func signatureGroup(_ account: Account) -> some View {
        let signatures = app.signatures[account.id] ?? []
        SectionHeader("SIGNATURES")
        GroupCard {
            ForEach(Array(signatures.enumerated()), id: \.element.id) { index, signature in
                NavigationLink(value: SettingsRoute.signature(account: account.id, id: signature.id)) {
                    ListRow(signature.displayName, icon: .pen, divider: index > 0) {
                        if signature.isDefault { ListRowValue(Text("Default")) }
                        ListRowChevron()
                    }
                }
                .buttonStyle(.plain)
            }
            NavigationLink(value: SettingsRoute.signature(account: account.id, id: nil)) {
                ListRow(Text("New signature"), icon: .plus, titleColor: .accentColor, divider: !signatures.isEmpty)
            }
            .buttonStyle(.plain)
        }
        GroupFootnote("New messages, replies and forwards from this account start with the default.")
    }

    @ViewBuilder
    private func signInAgainGroup(_ provider: OAuthProvider) -> some View {
        GroupCard {
            Button {
                Task { await app.signIn(with: provider, again: accountID, authenticate: webAuthenticationSession.authenticator) }
            } label: {
                ListRow(Text("Sign in again"), icon: .reload, titleColor: .accentColor, divider: false)
            }
            .buttonStyle(.plain)
            .disabled(app.isSigningIn)
        }
        GroupFootnote(provider == .google
            ? "Google ended this account’s sign-in. Nimbra opens Google to sign in again."
            : "Microsoft ended this account’s sign-in. Nimbra opens Microsoft to sign in again.")
    }

    @ViewBuilder
    private func removeGroup(_ account: Account) -> some View {
        GroupCard {
            Button { confirmsRemove = true } label: {
                ListRow(Text("Remove account"), icon: .trash, titleColor: .accentRose, iconColor: .accentRose, divider: false)
            }
            .buttonStyle(.plain)
        }
        GroupFootnote("Mail kept on this iPhone for this account is deleted. It stays on the server.")
    }
}
