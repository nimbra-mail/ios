import Foundation
import NimbraCore
import SwiftUI

/// A reader block's text with its spans: bold, italic, code and links. The engine gives
/// spans as UTF-8 byte offsets into the text; offsets outside it, or inside a character,
/// are left out rather than guessed.
nonisolated enum ReaderText {
    static func attributed(_ block: TextBlock) -> AttributedString {
        var text = AttributedString(block.text)
        let utf8 = block.text.utf8
        for span in block.spans where span.start < span.end {
            guard let start = utf8.index(utf8.startIndex, offsetBy: Int(span.start), limitedBy: utf8.endIndex),
                  let end = utf8.index(utf8.startIndex, offsetBy: Int(span.end), limitedBy: utf8.endIndex),
                  let lower = String.Index(start, within: block.text),
                  let upper = String.Index(end, within: block.text),
                  let range = Range(lower..<upper, in: text)
            else { continue }
            var intent: InlinePresentationIntent = []
            if span.bold { intent.insert(.stronglyEmphasized) }
            if span.italic { intent.insert(.emphasized) }
            if span.code { intent.insert(.code) }
            if !intent.isEmpty { text[range].inlinePresentationIntent = intent }
            // Already limited to http, https and mailto by the engine; checked again here.
            if let link = span.link, let url = URL(string: link), MailNavigation.leavesApp(url) {
                text[range].link = url
            }
        }
        return text
    }
}
