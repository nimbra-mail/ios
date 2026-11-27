import SwiftUI
import WebKit

/// A message's original HTML in a locked-down web view (`MailWebConfiguration`,
/// `MailDocument`, `MailNavigation`), as tall as the mail so it scrolls with the thread.
/// Tapped links go to `open` (the thread shows the address before leaving the app).
///
/// UIKit's `WKWebView` rather than SwiftUI's `WebView`: the mail view needs a content rule
/// list, scripts in a content world of their own, and the navigation type of each request.
struct MailHTMLView: View {
    let html: String
    let images: Bool
    let open: (URL) -> Void
    @Environment(AppModel.self) private var app
    @Environment(\.colorScheme) private var colorScheme
    @State private var height: CGFloat = 1

    var body: some View {
        let darken = colorScheme == .dark && app.readingOptions.darkEmails
        MailWebRepresentable(
            html: html, images: images, dark: colorScheme == .dark, darken: darken,
            fetch: { [app] url in await app.remoteImage(url) }, open: open, height: $height
        )
        .frame(height: height)
        .accessibilityLabel(Text("Message"))
    }
}

/// The web view and its delegate.
private struct MailWebRepresentable: UIViewRepresentable {
    let html: String
    let images: Bool
    let dark: Bool
    let darken: Bool
    let fetch: (String) async -> Data?
    let open: (URL) -> Void
    @Binding var height: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(fetch: fetch)
    }

    func makeUIView(context: Context) -> WKWebView {
        let coordinator = context.coordinator
        let view = WKWebView(frame: .zero, configuration: MailWebConfiguration.make(images: coordinator.images))
        view.navigationDelegate = coordinator
        view.uiDelegate = coordinator
        view.allowsLinkPreview = false
        view.allowsBackForwardNavigationGestures = false
        view.scrollView.isScrollEnabled = false
        view.scrollView.bounces = false
        view.scrollView.contentInsetAdjustmentBehavior = .never
        view.isInspectable = false
        coordinator.watch(view)
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        let coordinator = context.coordinator
        coordinator.open = open
        coordinator.onHeight = { height = $0 }
        coordinator.show(Shown(html: html, images: images, dark: dark, darken: darken), in: view)
    }

    static func dismantleUIView(_ view: WKWebView, coordinator: Coordinator) {
        coordinator.stop(view)
    }

    /// What the view shows: a change loads the document again.
    struct Shown: Equatable {
        let html: String
        let images: Bool
        let dark: Bool
        let darken: Bool
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let images: RemoteImageScheme
        var open: (URL) -> Void = { _ in }
        var onHeight: (CGFloat) -> Void = { _ in }
        private var shown: Shown?
        private var pendingLoads = 0
        private var loading: Task<Void, Never>?
        private var sizeWatch: NSKeyValueObservation?

        init(fetch: @escaping (String) async -> Data?) {
            images = RemoteImageScheme(fetch: fetch)
        }

        /// Follows the document's height: the view does not scroll, the thread does.
        func watch(_ view: WKWebView) {
            sizeWatch = view.scrollView.observe(\.contentSize, options: [.new]) { [weak self] _, change in
                // The new size comes with the change: the scroll view is not read here.
                let height = change.newValue?.height ?? 0
                MainActor.assumeIsolated {
                    guard let self, height > 0 else { return }
                    self.onHeight(height.rounded(.up))
                }
            }
        }

        func show(_ next: Shown, in view: WKWebView) {
            guard next != shown else { return }
            shown = next
            loading?.cancel()
            loading = Task { [weak self, weak view] in
                // Never mail without the rule list: it waits for it, and shows nothing
                // when it cannot be had.
                guard let rules = await MailContentRules.list(), !Task.isCancelled, let self, let view else { return }
                let controller = view.configuration.userContentController
                controller.removeAllContentRuleLists()
                controller.add(rules)
                MailWebConfiguration.install(on: controller, images: next.images, darken: next.darken)
                self.images.isAllowed = next.images
                view.overrideUserInterfaceStyle = next.dark ? .dark : .light
                // See-through while darkening, so the thread's page shows before the
                // mail's first paint; white otherwise, the page mail is written for.
                view.isOpaque = !next.darken
                view.backgroundColor = next.darken ? .clear : .white
                view.scrollView.backgroundColor = view.backgroundColor
                self.pendingLoads += 1
                view.loadHTMLString(MailDocument.html(next.html, images: next.images), baseURL: nil)
            }
        }

        func stop(_ view: WKWebView) {
            loading?.cancel()
            sizeWatch = nil
            view.stopLoading()
            view.navigationDelegate = nil
            view.uiDelegate = nil
        }

        // MARK: WKNavigationDelegate

        func webView(
            _ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
            preferences: WKWebpagePreferences
        ) async -> (WKNavigationActionPolicy, WKWebpagePreferences) {
            preferences.allowsContentJavaScript = false
            let decision = MailNavigation.decide(
                action.request.url, tapped: action.navigationType == .linkActivated,
                mainFrame: action.targetFrame?.isMainFrame ?? false, pendingLoads: pendingLoads
            )
            switch decision {
            case .load:
                pendingLoads -= 1
                return (.allow, preferences)
            case .open(let url):
                open(url)
                return (.cancel, preferences)
            case .cancel:
                return (.cancel, preferences)
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor response: WKNavigationResponse) async -> WKNavigationResponsePolicy {
            // Never a download, and only the document Nimbra handed it.
            response.canShowMIMEType && response.isForMainFrame ? .allow : .cancel
        }

        func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
            download.cancel { _ in }
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            // Shown again from the start.
            let last = shown
            shown = nil
            if let last { show(last, in: webView) }
        }

        // MARK: WKUIDelegate

        /// No pop-ups: `target="_blank"` links come here, and go where a tapped link goes.
        func webView(
            _ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
            for action: WKNavigationAction, windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if action.navigationType == .linkActivated, let url = action.request.url, MailNavigation.leavesApp(url) {
                open(url)
            }
            return nil
        }
    }
}
