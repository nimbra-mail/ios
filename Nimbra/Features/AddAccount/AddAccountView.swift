import AuthenticationServices
import SwiftUI

/// 09 · Add account: Google, Microsoft, or another address, each with a line on what it
/// covers.
struct AddAccountView: View {
    let close: () -> Void
    let otherAddress: () -> Void
    @Environment(AppModel.self) private var app
    @Environment(\.webAuthenticationSession) private var webAuthenticationSession

    var body: some View {
        VStack(spacing: 0) {
            SheetNavBar("Add account", leading: .close, action: close)
            ScrollView {
                VStack(spacing: 12) {
                    Text("Nimbra signs in with your provider. Your mail stays on this iPhone, encrypted.")
                        .nimbraText(.subhead)
                        .foregroundStyle(Color.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 4)
                        .padding(.bottom, 20)

                    ProviderButton(title: "Continue with Google") { signIn(.google) } logo: {
                        Image(.logoGoogle).resizable().frame(width: 20, height: 20)
                    }
                    footnote("Gmail and Google Workspace. You sign in on Google’s page.")

                    ProviderButton(title: "Continue with Microsoft") { signIn(.microsoft) } logo: {
                        MicrosoftLogo()
                    }
                    footnote("Outlook.com, Hotmail and Microsoft 365. You sign in on Microsoft’s page.")

                    ProviderButton(title: "Another address", action: otherAddress) {
                        Icon(.mail)
                    }
                    footnote("Zoho, iCloud, Fastmail, Yahoo or your own domain. Nimbra finds the servers.")
                }
                .disabled(app.isSigningIn)
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 40)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private func footnote(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .nimbraText(.footnote)
            .foregroundStyle(Color.textTertiary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 4)
            .padding(.top, 2)
            .padding(.bottom, 6)
    }

    private func signIn(_ provider: OAuthProvider) {
        Task {
            if await app.signIn(with: provider, authenticate: webAuthenticationSession.authenticator) {
                close()
            }
        }
    }
}

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
        AddAccountView(close: {}, otherAddress: {})
            .presentationBackground(Color.surfaceRaised)
            .presentationDragIndicator(.visible)
    }
    .environment(AppModel.sample())
}
