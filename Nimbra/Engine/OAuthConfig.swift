import Foundation
import NimbraCore

/// A provider Nimbra signs in with on its own page.
nonisolated enum OAuthProvider: Sendable, Hashable {
    case google, microsoft
}

/// The OAuth client ids this build was made with, from `Config/OAuth.xcconfig` through
/// Info.plist. Either may be missing (a build without the file): its button still shows,
/// and says sign-in is not set up. Client ids are public (an iOS client has no secret).
nonisolated struct OAuthConfig: Sendable, Equatable {
    /// `<number>-<id>.apps.googleusercontent.com`, Google's iOS client.
    let googleClientID: String?
    /// The Azure app registration's id (a GUID).
    let microsoftClientID: String?
    /// The app's bundle id, for Microsoft's redirect (`msauth.<bundle id>://auth`).
    let bundleID: String

    private static let googleSuffix = ".apps.googleusercontent.com"

    /// Keeps only ids of the right shape, so a typo turns sign-in off instead of stopping
    /// the engine (it refuses a Microsoft id that is not a GUID).
    init(googleClientID: String?, microsoftClientID: String?, bundleID: String) {
        let google = googleClientID?.trimmingCharacters(in: .whitespaces) ?? ""
        let prefix = google.hasSuffix(Self.googleSuffix) ? String(google.dropLast(Self.googleSuffix.count)) : ""
        let validPrefix = !prefix.isEmpty && prefix.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" }
        self.googleClientID = validPrefix ? google : nil
        let microsoft = microsoftClientID?.trimmingCharacters(in: .whitespaces) ?? ""
        self.microsoftClientID = UUID(uuidString: microsoft) != nil ? microsoft : nil
        self.bundleID = bundleID
    }

    /// From Info.plist (`NimbraGoogleClientID`, `NimbraMicrosoftClientID`).
    static var bundled: OAuthConfig {
        func value(_ key: String) -> String? {
            guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
                  !value.isEmpty, !value.hasPrefix("$(") else { return nil }
            return value
        }
        return OAuthConfig(
            googleClientID: value("NimbraGoogleClientID"),
            microsoftClientID: value("NimbraMicrosoftClientID"),
            bundleID: Bundle.main.bundleIdentifier ?? "com.riangle.nimbra"
        )
    }

    var engineConfig: EngineConfig {
        EngineConfig(googleClientId: googleClientID, googleClientSecret: nil, microsoftClientId: microsoftClientID)
    }

    /// Where the provider's page sends the browser back: a custom scheme the sign-in
    /// session catches. Nil when the provider is not set up in this build.
    func redirect(for provider: OAuthProvider) -> OAuthRedirect? {
        switch provider {
        case .google:
            guard let id = googleClientID else { return nil }
            // Google's iOS clients take their id reversed as the scheme.
            let scheme = "com.googleusercontent.apps." + id.dropLast(Self.googleSuffix.count)
            return OAuthRedirect(scheme: scheme, uri: "\(scheme):/oauth2redirect")
        case .microsoft:
            guard microsoftClientID != nil else { return nil }
            let scheme = "msauth.\(bundleID)"
            return OAuthRedirect(scheme: scheme, uri: "\(scheme)://auth")
        }
    }
}

/// A sign-in's redirect: the scheme the session waits for, and the full address the
/// provider is told.
nonisolated struct OAuthRedirect: Sendable, Equatable {
    let scheme: String
    let uri: String
}
