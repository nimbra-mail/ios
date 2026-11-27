import Foundation

/// The email's own HTML, made safe to hand the web view, as the Mac's `webview.rs` does.
///
/// Mail is hostile input. The document puts a Content-Security-Policy in front of it that
/// blocks everything remote (no scripts, frames, fonts, media, form posts or `<base>`
/// tricks); remote images are allowed only through Nimbra's own scheme
/// (`RemoteImageScheme`), which fetches them with the engine once the person allows them.
/// `<link>` tags are made inert, as the policy cannot stop a preconnect (which tells the
/// sender the mail was opened). The page's scripts are off in the web view as well
/// (`MailWebConfiguration`), and so is navigation (`MailNavigation`).
nonisolated enum MailDocument {
    /// What a message looks like when it brings no styling of its own: a readable
    /// sans-serif at the reading size. `:where()` gives the rules zero specificity, so
    /// anything the email sets wins, and they touch only inherited text properties. The
    /// rules that win are the space at the sides and no text inflation. The space lines
    /// the mail up with the header above it while its own background still fills the
    /// width.
    static let defaults = ":where(html){font:17px/1.55 -apple-system,'Helvetica Neue',Arial,sans-serif;overflow-wrap:break-word}"
        // iOS would enlarge the text of a page fitted to the width, past its line height.
        + "html{padding:0 20px!important;-webkit-text-size-adjust:none!important;text-size-adjust:none!important}"
        + "body{margin:0!important}"
        + ":where(pre,code,tt){font-family:ui-monospace,Menlo,monospace;font-size:0.92em}"
        + ":where(img){max-width:100%;height:auto}"

    /// The full document for `body`: the policy first, so it lands in `<head>` and applies
    /// before anything in the message is parsed.
    static func html(_ body: String, images: Bool) -> String {
        let img = images ? "data: \(RemoteImageScheme.name):" : "data:"
        return "<!doctype html><meta charset=\"utf-8\">"
            + "<meta http-equiv=\"Content-Security-Policy\" content=\"default-src 'none'; "
            + "img-src \(img); style-src 'unsafe-inline'; form-action 'none'; base-uri 'none'\">"
            + "<meta http-equiv=\"x-dns-prefetch-control\" content=\"off\">"
            + "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">"
            + "<style>\(defaults)</style>"
            + withoutLinks(body)
    }

    /// The mail with each `<link` start tag renamed to `<meta`, which is also empty, also
    /// allowed in the head, and ignores `rel` and `href`. A tag's name can only be written
    /// out literally (entities and NULs cannot spell one), in any letter case.
    static func withoutLinks(_ html: String) -> String {
        var out = ""
        out.reserveCapacity(html.utf8.count)
        let bytes = Array(html.utf8)
        var done = 0
        var at = 0
        while at < bytes.count {
            if bytes[at] == UInt8(ascii: "<"), at + 5 <= bytes.count,
               String(decoding: bytes[(at + 1)..<(at + 5)], as: UTF8.self).lowercased() == "link",
               at + 5 == bytes.count || [0x20, 0x09, 0x0A, 0x0D, 0x0C, 0x2F, 0x3E].contains(bytes[at + 5]) {
                out += String(decoding: bytes[done..<at], as: UTF8.self)
                out += "<meta"
                done = at + 5
                at += 5
            } else {
                at += 1
            }
        }
        out += String(decoding: bytes[done...], as: UTF8.self)
        return out
    }

    /// Whether the mail asks for images from the web (an `<img>`, a `background` or a CSS
    /// `url()` over http or https): what "Load images" would change.
    static func hasRemoteImages(_ html: String) -> Bool {
        html.range(of: #"(src|background|srcset)\s*=\s*["']?\s*https?:|url\(\s*["']?\s*https?:"#, options: [.regularExpression, .caseInsensitive]) != nil
    }
}
