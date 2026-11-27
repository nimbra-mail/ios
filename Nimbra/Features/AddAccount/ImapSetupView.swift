import Accessibility
import NimbraCore
import SwiftUI

/// 10 · IMAP setup: the address and password; Finding servers while Nimbra looks for them
/// and checks the password; the Servers typed in when they cannot be found; and what went
/// wrong (Error).
struct ImapSetupView: View {
    let leading: SheetNavBar.Leading
    /// Back to the providers, or closing the sheet.
    let leave: () -> Void
    /// The account was added.
    let done: () -> Void

    @Environment(AppModel.self) private var app
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @State private var setup = ImapSetup()
    @State private var showsPassword = false
    @FocusState private var focus: Field?

    private enum Field: Hashable {
        case email, password, incomingHost, incomingPort, outgoingHost, outgoingPort, username
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetNavBar("Another address", leading: setup.step == .servers ? .back : leading) {
                if setup.step == .servers { withAnimation(.smooth) { setup.backToForm() } } else { leave() }
            }
            ScrollView {
                VStack(spacing: 8) {
                    switch setup.step {
                    case .form: form
                    case .servers: servers
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 40)
                .animation(.smooth, value: setup.notice)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)
        }
        .onChange(of: setup.isDone) { _, isDone in
            if isDone { done() }
        }
        .onChange(of: setup.notice) { _, notice in
            announce(notice)
        }
        .onAppear { focus = .email }
    }

    // MARK: Address and password

    @ViewBuilder
    private var form: some View {
        GroupCard {
            FieldRow("Email", divider: false) {
                TextField("Email", text: $setup.email, prompt: Text.fieldPrompt(verbatim: "name@example.com"))
                    .textContentType(.username)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focus, equals: .email)
                    .submitLabel(.next)
                    .onSubmit { focus = .password }
            }
            FieldRow("Password", divider: true) {
                Group {
                    if showsPassword {
                        TextField("Password", text: $setup.password, prompt: Text.fieldPrompt("Required"))
                    } else {
                        SecureField("Password", text: $setup.password, prompt: Text.fieldPrompt("Required"))
                    }
                }
                .textContentType(.password)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focus, equals: .password)
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
        .opacity(setup.isChecking ? 0.5 : 1)
        .disabled(setup.isChecking)

        if let notice = setup.notice {
            noticeCard(notice)
        } else {
            Text("If your provider, like Google, gives you an app password, use that. It is kept in the Keychain on this iPhone.")
                .nimbraText(.footnote)
                .foregroundStyle(Color.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
                .padding(.top, 2)
                .padding(.bottom, 6)
        }

        Spacer().frame(height: 8)
        signInButton

        if !setup.isChecking {
            Button("Enter the servers yourself") {
                withAnimation(.smooth) { setup.enterServers() }
                focus = .incomingHost
            }
            .nimbraText(.bodyMedium)
            .foregroundStyle(Color.accentColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
    }

    // MARK: Servers

    @ViewBuilder
    private var servers: some View {
        if let notice = setup.notice {
            noticeCard(notice)
        }
        SectionHeader("INCOMING (IMAP)")
        serverCard($setup.incoming, host: .incomingHost, port: .incomingPort)
        SectionHeader("OUTGOING (SMTP)")
        serverCard($setup.outgoing, host: .outgoingHost, port: .outgoingPort)
        GroupCard {
            FieldRow("User name", divider: false) {
                TextField("User name", text: $setup.username, prompt: Text.fieldPrompt("Usually your address"))
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focus, equals: .username)
                    .submitLabel(.go)
                    .onSubmit(submit)
            }
        }
        .padding(.top, 8)
        Spacer().frame(height: 4)
        signInButton
    }

    private func serverCard(_ server: Binding<ServerFields>, host: Field, port: Field) -> some View {
        GroupCard {
            FieldRow("Server", divider: false) {
                TextField("Server", text: server.host, prompt: Text.fieldPrompt(verbatim: server.wrappedValue.suggestion))
                    .keyboardType(.URL)
                    .textContentType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focus, equals: host)
                    .submitLabel(.next)
                    .onSubmit { focus = port }
            }
            FieldRow("Port", divider: true) {
                TextField("Port", value: server.port, format: .number.grouping(.never))
                    .keyboardType(.numberPad)
                    .focused($focus, equals: port)
            }
            PickerRow(title: "Security", value: Text(Self.title(server.wrappedValue.security)), selection: server.security) {
                Text(Self.title(.tls)).tag(ServerSecurity.tls)
                Text(Self.title(.startTls)).tag(ServerSecurity.startTls)
            }
        }
        .opacity(setup.isChecking ? 0.5 : 1)
        .disabled(setup.isChecking)
    }

    // MARK: Shared

    private var signInButton: some View {
        PrimaryButton(setup.isChecking ? "Checking…" : "Sign in", action: submit)
            .disabled(!setup.canSubmit)
    }

    private func noticeCard(_ notice: ImapSetup.Notice) -> some View {
        GroupCard {
            switch notice {
            case .checking:
                NoticeRow(icon: .loader, iconColor: .accentColor, text: Text("Finding the servers and checking the password…"),
                          textColor: .textSecondary, spins: true)
            case .notFound:
                NoticeRow(icon: .alert, iconColor: .accentAmber, text: Text("Nimbra could not find this account’s servers. Check them below."))
            case .failed(let message), .refused(let message):
                NoticeRow(icon: .alert, iconColor: .accentRose, text: Text(verbatim: message))
            }
        }
        .transition(.opacity)
    }

    private func submit() {
        guard setup.canSubmit else { return }
        focus = nil
        Task {
            await setup.submit(with: app)
            // VoiceOver reads the notice instead, which moving the focus would cut off.
            if case .refused? = setup.notice, setup.step == .form, !voiceOver { focus = .password }
        }
    }

    private func announce(_ notice: ImapSetup.Notice?) {
        let words: String
        switch notice {
        case .notFound?: words = String(localized: "Nimbra could not find this account’s servers. Check them below.")
        case .failed(let message)?, .refused(let message)?: words = message
        case .checking?, nil: return
        }
        AccessibilityNotification.Announcement(words).post()
    }

    private static func title(_ security: ServerSecurity) -> LocalizedStringKey {
        switch security {
        case .tls: "SSL/TLS"
        case .startTls: "STARTTLS"
        }
    }
}

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
        ImapSetupView(leading: .back, leave: {}, done: {})
            .presentationBackground(Color.surfaceRaised)
            .presentationDragIndicator(.visible)
    }
    .environment(AppModel.sample())
}
