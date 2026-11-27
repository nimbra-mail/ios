import Foundation
import SwiftUI

/// A signature's HTML and the text editor's attributed text, both ways. The editor keeps
/// what a message's text has: bold, italic, underline and links, line by line; anything
/// more (images, tables, lists) is edited as HTML. The engine cleans what is kept, so this
/// only has to be faithful, not safe.
nonisolated enum SignatureHTML {
    /// Text read from HTML, and whether the text editor keeps all of it.
    struct Parsed {
        var text: AttributedString
        var isComplete: Bool
    }

    /// The tags the text editor keeps.
    private static let inline: Set<String> = ["b", "strong", "i", "em", "u", "a", "span", "font"]
    private static let blocks: Set<String> = ["div", "p", "br"]

    // MARK: HTML to text

    /// The HTML's text with its bold, italic, underline and links; bold and italic runs
    /// are `font` made bold or italic. For the preview (`preview`), lists get bullets and
    /// images a placeholder, as on the Mac.
    static func text(from html: String, font: Font, preview: Bool = false) -> Parsed {
        var text = AttributedString()
        var isComplete = true
        var bold = 0, italic = 0, underline = 0
        var links: [URL?] = []
        // A line ends before the next text, not at once: `<div>a</div><div>b</div>` is two
        // lines, with no empty one between them.
        var pendingBreak = false

        func append(_ string: String) {
            guard !string.isEmpty else { return }
            if pendingBreak, !text.characters.isEmpty { text.append(AttributedString("\n")) }
            pendingBreak = false
            var run = AttributedString(string)
            if bold > 0 || italic > 0 {
                run.font = styled(font, bold: bold > 0, italic: italic > 0)
            }
            if underline > 0 { run.underlineStyle = .single }
            if let link = links.last(where: { $0 != nil }) ?? nil { styleLink(&run, link) }
            text.append(run)
        }

        func lineBreak() {
            if pendingBreak { text.append(AttributedString("\n")) }
            pendingBreak = true
        }

        for token in tokens(html) {
            switch token {
            case .text(let string):
                append(collapsingSpace(decode(string)))
            case .open(let name, let attributes):
                switch name {
                case "b", "strong": bold += 1
                case "i", "em": italic += 1
                case "u": underline += 1
                case "a": links.append(attributes["href"].flatMap(safeURL))
                case "br": lineBreak()
                case "div", "p": if !text.characters.isEmpty { pendingBreak = true }
                case "span", "font": break
                case "li":
                    isComplete = false
                    if !text.characters.isEmpty { pendingBreak = true }
                    if preview { append("• ") }
                case "img":
                    isComplete = false
                    if preview {
                        let alt = attributes["alt"].map(decode) ?? ""
                        append(alt.isEmpty ? String(localized: "Image") : String(localized: "Image: \(alt)"))
                    }
                default:
                    isComplete = false
                    if blockLike.contains(name), !text.characters.isEmpty { pendingBreak = true }
                }
            case .close(let name):
                switch name {
                case "b", "strong": bold = max(0, bold - 1)
                case "i", "em": italic = max(0, italic - 1)
                case "u": underline = max(0, underline - 1)
                case "a": _ = links.popLast()
                case "div", "p": pendingBreak = true
                default: if blockLike.contains(name) { pendingBreak = true }
                }
            }
        }
        return Parsed(text: text, isComplete: isComplete)
    }

    private static let blockLike: Set<String> = ["ul", "ol", "li", "table", "tr", "blockquote", "h1", "h2", "h3", "pre", "hr"]

    /// The signature's font, bold or italic. Geist has no italic, so an italic run is in the
    /// system's italic at the same size (the HTML says `<i>`; mail apps show their own).
    static func styled(_ font: Font, bold: Bool, italic: Bool) -> Font {
        italic ? Font.body.italic().bold(bold) : font.bold(bold)
    }

    /// A link in the editor: in the accent and underlined, as a message shows it (the
    /// underline is the link's, not written as `<u>`).
    static func styleLink(_ text: inout AttributedString, _ url: URL) {
        text.link = url
        text.foregroundColor = .accentColor
        text.underlineStyle = .single
    }

    // MARK: Text to HTML

    /// The editor's text as HTML: a `<div>` per line (an empty one holds a `<br>`), as the
    /// engine writes text, with `<b>`, `<i>`, `<u>` and `<a>` around runs. `context`
    /// resolves the runs' fonts to tell bold and italic.
    static func html(from text: AttributedString, context: Font.Context) -> String {
        var lines: [String] = [""]
        for run in text.runs {
            let resolved = run.font?.resolve(in: context)
            var open = "", close = ""
            if let link = run.link, let href = safeURL(link.absoluteString) {
                open += "<a href=\"\(escape(href.absoluteString, quotes: true))\">"
                close = "</a>" + close
            }
            if resolved?.isBold == true { open += "<b>"; close = "</b>" + close }
            if resolved?.isItalic == true { open += "<i>"; close = "</i>" + close }
            if run.underlineStyle != nil, run.link == nil { open += "<u>"; close = "</u>" + close }

            let pieces = String(text[run.range].characters).split(separator: "\n", omittingEmptySubsequences: false)
            for (index, piece) in pieces.enumerated() {
                if index > 0 { lines.append("") }
                if !piece.isEmpty { lines[lines.count - 1] += open + escape(String(piece)) + close }
            }
        }
        // A last empty line is where the caret was: no line of its own.
        if lines.count > 1, lines.last?.isEmpty == true { lines.removeLast() }
        if lines == [""] { return "" }
        return lines.map { $0.isEmpty ? "<div><br></div>" : "<div>\($0)</div>" }.joined()
    }

    /// A link as typed: an address becomes `mailto:`, anything without a scheme `https://`.
    /// Only http, https and mailto, as the engine keeps.
    static func link(from typed: String) -> URL? {
        let typed = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !typed.isEmpty else { return nil }
        if typed.contains("@"), !typed.contains("/"), !typed.lowercased().hasPrefix("mailto:") {
            return safeURL("mailto:" + typed)
        }
        if typed.range(of: "^[A-Za-z][A-Za-z0-9+.-]*:", options: .regularExpression) == nil {
            return safeURL("https://" + typed)
        }
        return safeURL(typed)
    }

    private static func safeURL(_ string: String) -> URL? {
        guard let url = URL(string: string.trimmingCharacters(in: .whitespaces)),
              let scheme = url.scheme?.lowercased(), ["http", "https", "mailto"].contains(scheme) else { return nil }
        return url
    }

    // MARK: Tokens

    private enum Token {
        case text(String)
        case open(String, [String: String])
        case close(String)
    }

    /// Splits HTML into text and tags, dropping comments and what scripts and styles hold.
    private static func tokens(_ html: String) -> [Token] {
        var tokens: [Token] = []
        var rest = Substring(html)
        var skipping: String?
        while !rest.isEmpty {
            guard let start = rest.firstIndex(of: "<") else {
                if skipping == nil { tokens.append(.text(String(rest))) }
                break
            }
            if start > rest.startIndex, skipping == nil { tokens.append(.text(String(rest[..<start]))) }
            rest = rest[start...]
            if rest.hasPrefix("<!--") {
                rest = rest.range(of: "-->").map { rest[$0.upperBound...] } ?? ""
                continue
            }
            guard let end = rest.firstIndex(of: ">") else { break }
            let inside = rest[rest.index(after: rest.startIndex)..<end].trimmingCharacters(in: .whitespacesAndNewlines)
            rest = rest[rest.index(after: end)...]
            if inside.hasPrefix("/") {
                let name = inside.dropFirst().trimmingCharacters(in: .whitespaces).lowercased()
                if skipping == name { skipping = nil; continue }
                if skipping == nil { tokens.append(.close(name)) }
                continue
            }
            guard skipping == nil, !inside.hasPrefix("!") else { continue }
            let name = String(inside.prefix { !$0.isWhitespace && $0 != "/" }).lowercased()
            if name == "script" || name == "style" { skipping = name; continue }
            tokens.append(.open(name, attributes(String(inside.dropFirst(name.count)))))
        }
        return tokens
    }

    /// A tag's attributes, names in lower case and values decoded.
    private static func attributes(_ string: String) -> [String: String] {
        var result: [String: String] = [:]
        let pattern = /([A-Za-z_:][-A-Za-z0-9_:.]*)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'>]+))/
        for match in string.matches(of: pattern) {
            let value = match.output.2 ?? match.output.3 ?? match.output.4 ?? ""
            result[String(match.output.1).lowercased()] = decode(String(value))
        }
        return result
    }

    private static func collapsingSpace(_ string: String) -> String {
        string.replacing(/\s+/, with: " ")
    }

    // MARK: Entities

    private static let named: [String: String] = [
        "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "#39": "'", "nbsp": "\u{00A0}",
    ]

    static func decode(_ string: String) -> String {
        guard string.contains("&") else { return string }
        return string.replacing(/&(#[0-9]+|#[xX][0-9A-Fa-f]+|[A-Za-z]+);/) { match in
            let entity = String(match.output.1)
            if let known = named[entity] { return known }
            let number: UInt32? = if entity.hasPrefix("#x") || entity.hasPrefix("#X") {
                UInt32(entity.dropFirst(2), radix: 16)
            } else if entity.hasPrefix("#") {
                UInt32(entity.dropFirst())
            } else {
                nil
            }
            return number.flatMap(Unicode.Scalar.init).map { String(Character($0)) } ?? String(match.output.0)
        }
    }

    static func escape(_ string: String, quotes: Bool = false) -> String {
        var escaped = string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
        if quotes { escaped = escaped.replacingOccurrences(of: "\"", with: "&quot;") }
        return escaped
    }
}
