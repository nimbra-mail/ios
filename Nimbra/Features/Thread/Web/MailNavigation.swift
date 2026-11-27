import Foundation

/// Where the mail view may go: nowhere. Only the document Nimbra hands it loads; a link the
/// person tapped to the web or to mail is handed to the app (which shows the address
/// first); everything else the mail starts by itself (a meta refresh needs no script, a
/// frame, a form) is cancelled. As the Mac's `webview.rs`.
nonisolated enum MailNavigation: Equatable {
    /// The document Nimbra handed the view.
    case load
    /// A tapped link, for the app to open. The view stays where it is.
    case open(URL)
    case cancel

    /// - Parameters:
    ///   - tapped: the person tapped a link (WebKit's `linkActivated`).
    ///   - mainFrame: it would load in the page itself, not in a frame.
    ///   - pendingLoads: documents Nimbra handed the view that have not started.
    static func decide(_ url: URL?, tapped: Bool, mainFrame: Bool, pendingLoads: Int) -> MailNavigation {
        guard let url else { return .cancel }
        if !tapped, mainFrame, pendingLoads > 0, url.absoluteString == "about:blank" {
            return .load
        }
        if tapped, leavesApp(url) { return .open(url) }
        return .cancel
    }

    /// Only web and mail links may leave the app.
    static func leavesApp(_ url: URL) -> Bool {
        switch url.scheme?.lowercased() {
        case "http", "https": url.host() != nil
        case "mailto": true
        default: false
        }
    }
}
