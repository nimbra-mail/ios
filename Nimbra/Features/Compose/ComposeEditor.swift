import SwiftUI
import WebKit

/// The message editor: the Mac's editor (`ComposeEditor.html`, a port of the desktop's
/// `editor.html`) in a locked-down web view, so what is written is the same HTML the Mac
/// writes and the engine expects (a `<div>` per line, `<b>`, `<i>`, `<u>`, lists and
/// links), the signature shows as the HTML it is, and a saved draft reopens as it was.
///
/// Locked down: its page loads nothing (a Content Security Policy with only its own
/// script, fonts and images inlined), keeps nothing (a non-persistent data store), and
/// follows no link; pasted HTML is cut down to plain formatting before it goes in.
struct ComposeEditor: UIViewRepresentable {
    let editor: ComposeEditorModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func makeUIView(context: Context) -> WKWebView {
        editor.makeWebView()
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Colors and sizes follow the appearance and Dynamic Type.
        editor.applyTheme(colorScheme: colorScheme, dynamicTypeSize: dynamicTypeSize)
    }
}

/// Drives the editor's page and keeps what it reports: the formatting at the caret, for
/// the formatting bar.
@Observable
final class ComposeEditorModel: NSObject {
    private(set) var isBold = false
    private(set) var isItalic = false
    private(set) var isUnderlined = false
    private(set) var isBulleted = false
    /// The link at the caret, if any.
    private(set) var link: String?
    private(set) var hasSelection = false
    private(set) var isFocused = false

    /// What was written changed: its HTML and its text.
    @ObservationIgnored var changed: (String, String) -> Void = { _, _ in }
    /// The signature as the page shows it, as text.
    @ObservationIgnored var signatureText: (String) -> Void = { _ in }
    /// The signature's handle was tapped.
    @ObservationIgnored var signatureMenu: () -> Void = {}
    @ObservationIgnored var focused: () -> Void = {}
    /// The page is ready (again, after the system reclaimed it): load what is written.
    @ObservationIgnored var ready: () -> Void = {}

    @ObservationIgnored private var webView: WKWebView?
    @ObservationIgnored private var isReady = false
    @ObservationIgnored private var waiting: [String] = []
    @ObservationIgnored private var theme: [String: String] = [:]

    func makeWebView() -> WKWebView {
        if let webView { return webView }
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.dataDetectorTypes = []
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        configuration.userContentController.add(WeakHandler(self), name: "nimbra")
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.keyboardDismissMode = .interactive
        webView.allowsLinkPreview = false
        webView.navigationDelegate = self
        webView.loadHTMLString(Self.page(), baseURL: nil)
        self.webView = webView
        return webView
    }

    // MARK: Commands

    /// Puts what is written, and the quote folded under it, into the editor.
    func load(html: String, quoted: String?, focus: Bool) {
        run("nimbra.load(\(Self.js(html)), \(Self.js(quoted ?? "")), \(focus))")
    }

    /// Shows the signature (already cleaned by the engine), or the handle alone.
    func showSignature(_ html: String?) {
        run("nimbra.signature(\(Self.js(html ?? "")))")
    }

    /// Bold, italic, underline, a bulleted list: on the selection or what comes next.
    func exec(_ command: String) {
        run("nimbra.exec(\(Self.js(command)))")
    }

    /// Links the selection to `value` (an address becomes `mailto:`), or unlinks with "".
    func setLink(_ value: String) {
        run("nimbra.link(\(Self.js(value)))")
    }

    func focus() { run("nimbra.focus()") }

    func blur() { run("nimbra.blur()") }

    /// The app's colors and type at the current appearance and Dynamic Type size.
    func applyTheme(colorScheme: ColorScheme, dynamicTypeSize: DynamicTypeSize) {
        let traits = UITraitCollection { traits in
            traits.userInterfaceStyle = colorScheme == .dark ? .dark : .light
            traits.preferredContentSizeCategory = UIContentSizeCategory(dynamicTypeSize)
        }
        func css(_ color: UIColor) -> String {
            var (r, g, b, a): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
            color.resolvedColor(with: traits).getRed(&r, green: &g, blue: &b, alpha: &a)
            return "rgba(\(Int(r * 255)),\(Int(g * 255)),\(Int(b * 255)),\(a))"
        }
        func px(_ style: NimbraTextStyle, _ value: CGFloat) -> String {
            let metrics = UIFontMetrics(forTextStyle: UIFont.TextStyle(style.relativeTo))
            return "\(metrics.scaledValue(for: value, compatibleWith: traits))px"
        }
        let theme = [
            "--text": css(UIColor(resource: .textPrimary)),
            "--dim": css(UIColor(resource: .textTertiary)),
            "--faint": css(UIColor(resource: .textFaint)),
            "--accent": css(UIColor(resource: .accent)),
            "--line": css(UIColor(resource: .borderStrong)),
            "--size": px(.reading, NimbraTextStyle.reading.size),
            "--leading": px(.reading, NimbraTextStyle.reading.lineHeight),
            "--tracking": "\(NimbraTextStyle.reading.tracking)px",
            "--small": px(.subhead, NimbraTextStyle.subhead.size),
            "--small-leading": px(.subhead, NimbraTextStyle.subhead.lineHeight),
            "--small-tracking": "\(NimbraTextStyle.subhead.tracking)px",
        ]
        guard theme != self.theme else { return }
        self.theme = theme
        let object = theme.map { "\(Self.js($0.key)): \(Self.js($0.value))" }.joined(separator: ", ")
        run("nimbra.theme({\(object)})")
    }

    /// The page's words, in the app's language.
    private func setWords() {
        let words = [
            String(localized: "Message"),
            String(localized: "Add signature"),
            String(localized: "Show the quoted message"),
            String(localized: "Signature"),
        ].map(Self.js).joined(separator: ", ")
        run("nimbra.words(\(words))")
    }

    private func run(_ script: String) {
        guard isReady, let webView else {
            waiting.append(script)
            return
        }
        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    // MARK: The page

    fileprivate func received(_ body: Any) {
        guard let message = body as? [String: Any], let kind = message["t"] as? String else { return }
        switch kind {
        case "ready":
            isReady = true
            setWords()
            let queued = waiting
            waiting = []
            queued.forEach(run)
            if !theme.isEmpty {
                let object = theme.map { "\(Self.js($0.key)): \(Self.js($0.value))" }.joined(separator: ", ")
                run("nimbra.theme({\(object)})")
            }
            ready()
        case "change":
            changed(message["html"] as? String ?? "", message["text"] as? String ?? "")
        case "state":
            isBold = message["b"] as? Bool ?? false
            isItalic = message["i"] as? Bool ?? false
            isUnderlined = message["u"] as? Bool ?? false
            isBulleted = message["ul"] as? Bool ?? false
            link = message["link"] as? String
            hasSelection = message["selected"] as? Bool ?? false
        case "signature":
            signatureText(message["text"] as? String ?? "")
        case "sigmenu":
            signatureMenu()
        case "focus":
            isFocused = true
            focused()
        default:
            break
        }
    }

    /// A string as a JavaScript literal (JSON's escaping).
    private static func js(_ value: String) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: [value]),
              let array = String(data: data, encoding: .utf8) else { return "\"\"" }
        return String(array.dropFirst().dropLast())
    }

    /// The page, with a fresh nonce for its one script and the fonts inlined (it loads
    /// nothing).
    private static func page() -> String {
        let nonce = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        return template
            .replacingOccurrences(of: "__NONCE__", with: nonce)
            .replacingOccurrences(of: "__REGULAR__", with: fonts.regular)
            .replacingOccurrences(of: "__BOLD__", with: fonts.bold)
    }

    private static let template: String = {
        guard let url = Bundle.main.url(forResource: "ComposeEditor", withExtension: "html"),
              let page = try? String(contentsOf: url, encoding: .utf8) else { return "" }
        return page
    }()

    private static let fonts: (regular: String, bold: String) = {
        func base64(_ name: String) -> String {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf"),
                  let data = try? Data(contentsOf: url) else { return "" }
            return data.base64EncodedString()
        }
        // Geist has no Bold in the app: SemiBold stands in, as on the screens.
        return (base64("Geist-Regular"), base64("Geist-SemiBold"))
    }()
}

extension ComposeEditorModel: WKNavigationDelegate {
    /// Only the editor's own page loads: no link, form or redirect goes anywhere.
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction) async -> WKNavigationActionPolicy {
        action.navigationType == .other && action.request.url?.absoluteString == "about:blank" ? .allow : .cancel
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        // The page went away (memory): start it again; `ready` loads what is written.
        isReady = false
        waiting = []
        webView.loadHTMLString(Self.page(), baseURL: nil)
    }
}

/// Holds the page's message handler weakly: the content controller keeps its handlers.
private final class WeakHandler: NSObject, WKScriptMessageHandler {
    weak var editor: ComposeEditorModel?

    init(_ editor: ComposeEditorModel) {
        self.editor = editor
    }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        editor?.received(message.body)
    }
}

private extension UIFont.TextStyle {
    init(_ style: Font.TextStyle) {
        self = switch style {
        case .largeTitle: .largeTitle
        case .title: .title1
        case .title2: .title2
        case .title3: .title3
        case .headline: .headline
        case .subheadline: .subheadline
        case .callout: .callout
        case .footnote: .footnote
        case .caption: .caption1
        case .caption2: .caption2
        default: .body
        }
    }
}
