import Foundation
import NimbraCore

/// What went wrong, in the states the app shows: the engine's `NimbraError`, and what only
/// the app knows (a sign-in that is not set up in this build).
nonisolated enum MailError: Error, Equatable, Sendable {
    /// The account's sign-in is gone (revoked, expired, a password changed): sign in again.
    /// Nil when it is the address being added that did not take the password or sign-in.
    case signedOut(accountID: String?)
    /// As `signedOut`, for a Google account's own password: Gmail takes only an app password
    /// once 2-Step Verification is on.
    case needsAppPassword(accountID: String?)
    /// No connection to the server.
    case offline
    /// The thread, message, draft or label is gone.
    case notFound
    /// The change feed is too old: the mailbox is listed afresh.
    case historyExpired
    /// Deleting for good needs one more permission from Google.
    case needsFullAccess
    /// The Keychain could not be read (the device is still locked after a restart, most
    /// likely). Never "signed out".
    case keychain
    /// What was asked is not valid. The engine's words, made to be shown.
    case invalid(String)
    /// Anything else. The engine's words, made to be shown.
    case failed(String)
    /// This build has no client id for the provider (`Config/OAuth.xcconfig`).
    case notConfigured(OAuthProvider)

    /// Maps what an engine call threw. Engine messages never carry a secret.
    init(_ error: any Error) {
        switch error {
        case let error as MailError:
            self = error
        case let error as NimbraError:
            switch error {
            case .SignedOut(let accountId): self = .signedOut(accountID: accountId)
            case .NeedsAppPassword(let accountId): self = .needsAppPassword(accountID: accountId)
            case .Offline: self = .offline
            case .NotFound: self = .notFound
            case .HistoryExpired: self = .historyExpired
            case .NeedsFullAccess: self = .needsFullAccess
            case .Keychain: self = .keychain
            case .Invalid(let message): self = .invalid(message)
            case .Failed(let message): self = .failed(message)
            }
        default:
            self = .failed(String(localized: "Something went wrong. Try again."))
        }
    }

    /// One or two sentences for an alert or a notice row.
    var message: String {
        switch self {
        case .signedOut, .needsAppPassword:
            String(localized: "This account was signed out. Sign in again to keep getting mail.")
        case .offline:
            String(localized: "You’re offline. Nimbra shows what is on this iPhone and catches up when you’re back.")
        case .notFound:
            String(localized: "It is not there any more.")
        case .historyExpired:
            String(localized: "The mailbox is being listed again.")
        case .needsFullAccess:
            String(localized: "Deleting for good needs one more permission from Google.")
        case .keychain:
            String(localized: "Nimbra could not read its Keychain. Unlock your iPhone and try again.")
        case .invalid(let message), .failed(let message):
            message
        case .notConfigured(let provider):
            switch provider {
            case .google: String(localized: "Sign-in with Google isn’t set up in this build of Nimbra.")
            case .microsoft: String(localized: "Sign-in with Microsoft isn’t set up in this build of Nimbra.")
            }
        }
    }
}
