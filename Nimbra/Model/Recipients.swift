import Foundation
import NimbraCore

/// Addresses as the To, Cc and Bcc fields take them, as the Mac does: a comma or a
/// semicolon ends one, "Name <address>" keeps the address, and each is a chip once.
nonisolated enum Recipients {
    /// Takes the finished addresses out of what is typed. `all` finishes the last one too
    /// (leaving the field, Return); otherwise what follows the last separator is still
    /// being typed. What is not an address stays in the text, to be fixed.
    static func chipify(_ text: String, into chips: [String], all: Bool) -> (chips: [String], rest: String) {
        var parts = text.split(separator: /[,;]/, omittingEmptySubsequences: false).map(String.init)
        let last = all ? "" : (parts.popLast() ?? "")
        var chips = chips
        var kept: [String] = []
        for part in parts {
            let part = part.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !part.isEmpty else { continue }
            let address = address(of: part)
            if isEmailAddress(text: address) {
                if !chips.contains(where: { $0.caseInsensitiveCompare(address) == .orderedSame }) {
                    chips.append(address)
                }
            } else {
                kept.append(part)
            }
        }
        var rest = kept.joined(separator: ", ")
        let typing = last.drop { $0.isWhitespace }
        if !typing.isEmpty {
            if !rest.isEmpty { rest += ", " }
            rest += typing
        }
        return (chips, rest)
    }

    /// The bare address of "Name <address>", or the text itself.
    static func address(of text: String) -> String {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let open = text.lastIndex(of: "<"), let close = text.lastIndex(of: ">"), open < close {
            return text[text.index(after: open)..<close].trimmingCharacters(in: .whitespaces)
        }
        return text
    }

    /// A field as the engine takes it.
    static func field(_ chips: [String], typing: String = "") -> String {
        let typing = typing.trimmingCharacters(in: .whitespacesAndNewlines)
        return (chips + (typing.isEmpty ? [] : [typing])).joined(separator: ", ")
    }

    /// A saved field ("a@x.com, Ben <b@y.com>") as chips.
    static func chips(_ field: String) -> [String] {
        let found = chipify(field, into: [], all: true)
        return found.rest.isEmpty ? found.chips : found.chips + [found.rest]
    }
}
