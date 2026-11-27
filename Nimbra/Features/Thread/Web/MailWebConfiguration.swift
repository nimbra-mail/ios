import UIKit
import WebKit

/// The web view settings for showing mail, as locked down as the Mac's (`webview.rs`):
/// - The mail's JavaScript is off. The only scripts are Nimbra's own (`mail_fit.js`,
///   `mail_images.js` once images are allowed, `dark_mail.js` when darkening), in a
///   content world of their own that the page cannot reach.
/// - Nothing is kept: a non-persistent data store, so mail cannot set lasting cookies or
///   storage.
/// - No pop-ups, no link previews (a preview would load the page), no data detectors
///   (they would make links out of text), no media playback, no AirPlay or Picture in
///   Picture.
/// - Remote images only through `RemoteImageScheme`; `MailContentRules` blocks the web.
enum MailWebConfiguration {
    /// The world Nimbra's scripts run in, apart from the page's.
    static let world = WKContentWorld.world(name: "Nimbra")

    static func make(images: RemoteImageScheme) -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        configuration.defaultWebpagePreferences.preferredContentMode = .mobile
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        configuration.preferences.isFraudulentWebsiteWarningEnabled = true
        configuration.preferences.isTextInteractionEnabled = true
        configuration.dataDetectorTypes = []
        configuration.allowsInlineMediaPlayback = false
        configuration.mediaTypesRequiringUserActionForPlayback = .all
        configuration.allowsAirPlayForMediaPlayback = false
        configuration.allowsPictureInPictureMediaPlayback = false
        configuration.upgradeKnownHostsToHTTPS = true
        configuration.suppressesIncrementalRendering = true
        configuration.setURLSchemeHandler(images, forURLScheme: RemoteImageScheme.name)
        return configuration
    }

    /// Puts Nimbra's scripts in for the next document: fitting always, images when
    /// allowed, darkening when the page is to be dark.
    static func install(on controller: WKUserContentController, images: Bool, darken: Bool) {
        controller.removeAllUserScripts()
        if let fit = script("mail_fit") {
            controller.addUserScript(WKUserScript(source: fit, injectionTime: .atDocumentStart, forMainFrameOnly: true, in: world))
        }
        if images, let swap = script("mail_images") {
            controller.addUserScript(WKUserScript(source: swap, injectionTime: .atDocumentStart, forMainFrameOnly: true, in: world))
        }
        if darken, let dark = darkScript() {
            controller.addUserScript(WKUserScript(source: dark, injectionTime: .atDocumentStart, forMainFrameOnly: true, in: world))
        }
    }

    /// `dark_mail.js` with the page colour it darkens to set to `bg/list` (Dark), from the
    /// colour set rather than written twice.
    static func darkScript() -> String? {
        guard let source = script("dark_mail") else { return nil }
        let surface = UIColor(resource: .bgList).resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard surface.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return source }
        let rgb = [red, green, blue].map { String(Int(($0 * 255).rounded())) }.joined(separator: ", ")
        return source.replacingOccurrences(of: "const SURFACE = [14, 14, 20];", with: "const SURFACE = [\(rgb)];")
    }

    /// One of the scripts in the app's bundle.
    static func script(_ name: String) -> String? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "js") else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }
}
