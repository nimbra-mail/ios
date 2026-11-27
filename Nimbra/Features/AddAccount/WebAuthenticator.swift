import AuthenticationServices
import SwiftUI

extension WebAuthenticationSession {
    /// The provider's page in the system's sign-in sheet, coming back to the app's own
    /// scheme. Nil when the person closes it.
    ///
    /// The session is ephemeral: it neither reads nor leaves the browser's cookies. Each
    /// account added is then the one the person signs in to on the page, never one Safari
    /// happened to be signed in to, and no Google or Microsoft session is left behind in
    /// the browser. Passwords still fill from the Keychain.
    var authenticator: WebAuthenticator {
        { url, scheme in
            do {
                return try await authenticate(
                    using: url,
                    callback: .customScheme(scheme),
                    preferredBrowserSession: .ephemeral,
                    additionalHeaderFields: [:]
                )
            } catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {
                return nil
            }
        }
    }
}
