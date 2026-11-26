import Foundation
import NimbraCore
import Observation

/// 10 · IMAP setup, step by step: the address and password; then Nimbra finds the servers
/// and checks the password on both; the servers typed in when they could not be found
/// (or the person chose to); and what went wrong, in words to act on.
@Observable
final class ImapSetup {
    enum Step: Equatable {
        /// The address and the password.
        case form
        /// The servers, typed in.
        case servers
    }

    /// What the notice row under the fields says.
    enum Notice: Equatable {
        /// Finding the servers and checking the password.
        case checking
        /// The servers were not found: they are typed in below.
        case notFound
        case failed(String)
    }

    var step = Step.form
    var notice: Notice?
    var email = ""
    var password = ""
    var incoming = ServerFields(.imap)
    var outgoing = ServerFields(.smtp)
    var username = ""
    /// The account was added: the sheet can close.
    var isDone = false

    var isChecking: Bool { notice == .checking }

    var canSubmit: Bool {
        guard !isChecking, isEmailAddress(text: email.trimmingCharacters(in: .whitespaces)), !password.isEmpty else { return false }
        return step == .form || (incoming.isComplete && outgoing.isComplete)
    }

    /// Sign in: on the form, finds the servers first; with the servers typed in, uses them.
    func submit(with app: AppModel) async {
        guard canSubmit else { return }
        notice = .checking
        switch step {
        case .form:
            do throws(MailError) {
                switch try await app.discoverServers(email: email) {
                case .servers(let servers):
                    fill(servers)
                    await add(servers, with: app)
                case .needsOAuth(let provider):
                    notice = .failed(Self.needsOAuth(provider))
                case .unknown:
                    suggestServers()
                    step = .servers
                    notice = .notFound
                }
            } catch {
                notice = .failed(Self.message(error))
            }
        case .servers:
            await add(servers, with: app)
        }
    }

    /// "Enter the servers yourself": the servers step, with what is known filled in.
    func enterServers() {
        suggestServers()
        notice = nil
        step = .servers
    }

    /// Back from the servers to the address and password.
    func backToForm() {
        step = .form
        notice = nil
    }

    /// The servers as typed.
    var servers: MailServers {
        let address = email.trimmingCharacters(in: .whitespaces)
        let user = username.trimmingCharacters(in: .whitespaces)
        return MailServers(username: user.isEmpty ? address : user, imap: incoming.server, smtp: outgoing.server)
    }

    private func add(_ servers: MailServers, with app: AppModel) async {
        do throws(MailError) {
            try await app.addImapAccount(email: email, servers: servers, password: password)
            notice = nil
            isDone = true
        } catch {
            notice = .failed(Self.message(error))
        }
    }

    private func fill(_ servers: MailServers) {
        incoming = ServerFields(.imap, server: servers.imap)
        outgoing = ServerFields(.smtp, server: servers.smtp)
        username = servers.username
    }

    /// The domain's usual server names, shown as placeholders until typed over.
    private func suggestServers() {
        let domain = email.split(separator: "@").last.map(String.init) ?? ""
        incoming.suggestion = domain.isEmpty ? "" : "imap.\(domain)"
        outgoing.suggestion = domain.isEmpty ? "" : "smtp.\(domain)"
    }

    /// What a failure means here: a password the server refused is a password to check.
    static func message(_ error: MailError) -> String {
        switch error {
        case .signedOut:
            String(localized: "The server did not take that password. Check it, or use an app password.")
        case .offline:
            String(localized: "Nimbra could not reach the server. Check your connection and the server’s name.")
        default:
            error.message
        }
    }

    private static func needsOAuth(_ provider: String) -> String {
        switch provider {
        case "Google": String(localized: "This address signs in with Google. Go back and choose Continue with Google.")
        case "Microsoft": String(localized: "This address signs in with Microsoft. Go back and choose Continue with Microsoft.")
        default: String(localized: "\(provider) only lets mail apps in through its own sign-in, which Nimbra does not have yet.")
        }
    }
}

/// One server as typed: its name, port and security.
nonisolated struct ServerFields: Equatable, Sendable {
    /// Which of the two servers it is, for its usual ports.
    nonisolated enum Role: Sendable {
        case imap, smtp

        func port(_ security: ServerSecurity) -> Int {
            switch (self, security) {
            case (.imap, .tls): 993
            case (.imap, .startTls): 143
            case (.smtp, .tls): 465
            case (.smtp, .startTls): 587
            }
        }
    }

    let role: Role
    var host = ""
    var port: Int
    /// Changing it moves the port along while it is still the usual one.
    var security: ServerSecurity {
        didSet {
            if port == role.port(oldValue) { port = role.port(security) }
        }
    }
    /// The usual name for it, shown until one is typed.
    var suggestion = ""

    init(_ role: Role, security: ServerSecurity = .tls) {
        self.role = role
        self.port = role.port(security)
        self.security = security
    }

    init(_ role: Role, server: MailServer) {
        self.role = role
        host = server.host
        port = Int(server.port)
        security = server.security
    }

    var isComplete: Bool {
        !resolvedHost.isEmpty && (1 ... 65535).contains(port)
    }

    /// The name typed, else the suggestion.
    private var resolvedHost: String {
        let typed = host.trimmingCharacters(in: .whitespaces)
        return typed.isEmpty ? suggestion : typed
    }

    var server: MailServer {
        MailServer(host: resolvedHost, port: UInt16(clamping: port), security: security)
    }
}
