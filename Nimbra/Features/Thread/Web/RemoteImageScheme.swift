import Foundation
import UniformTypeIdentifiers
import WebKit

/// Remote images in the mail view, fetched by the engine rather than the web view: the
/// image script (`mail_images.js`) points an `<img>` at `nimbra-image:https://…`, and this
/// handler answers it with `AppModel.remoteImage` (https on a public host only, checked at
/// every redirect, size-capped). The web view itself never reaches the network.
final class RemoteImageScheme: NSObject, WKURLSchemeHandler {
    static let name = "nimbra-image"

    /// Whether images may load now: the handler refuses them until they are allowed.
    var isAllowed = false
    private let fetch: (String) async -> Data?
    private var running: [ObjectIdentifier: Task<Void, Never>] = [:]

    init(fetch: @escaping (String) async -> Data?) {
        self.fetch = fetch
    }

    /// The https address an image URL stands for, or nil when it is not one.
    nonisolated static func remoteURL(_ url: URL) -> String? {
        let text = url.absoluteString
        let prefix = "\(name):"
        guard text.lowercased().hasPrefix(prefix) else { return nil }
        let remote = String(text.dropFirst(prefix.count))
        guard let parsed = URL(string: remote), parsed.scheme?.lowercased() == "https", parsed.host() != nil else { return nil }
        return remote
    }

    /// The image type its first bytes say, for the response.
    nonisolated static func mimeType(_ data: Data) -> String {
        let head = [UInt8](data.prefix(16))
        func starts(_ bytes: [UInt8], at offset: Int = 0) -> Bool {
            head.count >= offset + bytes.count && Array(head[offset..<(offset + bytes.count)]) == bytes
        }
        if starts([0x89, 0x50, 0x4E, 0x47]) { return "image/png" }
        if starts([0xFF, 0xD8, 0xFF]) { return "image/jpeg" }
        if starts([0x47, 0x49, 0x46, 0x38]) { return "image/gif" }
        if starts([0x52, 0x49, 0x46, 0x46]), starts([0x57, 0x45, 0x42, 0x50], at: 8) { return "image/webp" }
        if starts([0x66, 0x74, 0x79, 0x70], at: 4) { return "image/heic" }
        let text = String(decoding: data.prefix(256), as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if text.hasPrefix("<svg") || (text.hasPrefix("<?xml") && text.contains("<svg")) { return "image/svg+xml" }
        return "application/octet-stream"
    }

    func webView(_ webView: WKWebView, start task: any WKURLSchemeTask) {
        let key = ObjectIdentifier(task)
        guard isAllowed, let url = task.request.url, let remote = Self.remoteURL(url) else {
            task.didFailWithError(URLError(.resourceUnavailable))
            return
        }
        running[key] = Task { [weak self] in
            let data = await self?.fetch(remote)
            // A task WebKit stopped must not be answered.
            guard let self, self.running.removeValue(forKey: key) != nil else { return }
            guard let data, !Task.isCancelled else {
                task.didFailWithError(URLError(.resourceUnavailable))
                return
            }
            task.didReceive(URLResponse(url: url, mimeType: Self.mimeType(data), expectedContentLength: data.count, textEncodingName: nil))
            task.didReceive(data)
            task.didFinish()
        }
    }

    func webView(_ webView: WKWebView, stop task: any WKURLSchemeTask) {
        running.removeValue(forKey: ObjectIdentifier(task))?.cancel()
    }
}
