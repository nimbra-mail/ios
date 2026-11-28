/// How a thread's messages show under its subject: oldest first and the latest last, as the
/// Mac shows a conversation (or newest first, as Settings › Appearance may say); folded ones
/// together in a card, each open one on its own. The latest is open until it is folded.
nonisolated enum Folding {
    /// The messages (oldest first, as a thread keeps them) in the order shown.
    static func ordered(_ messages: [Message], newestFirst: Bool) -> [Message] {
        newestFirst ? messages.reversed() : messages
    }

    /// The messages shown open: the ones opened by hand, and the latest unless it was folded.
    static func open(_ messages: [Message], expanded: Set<Message.ID>, latestFolded: Bool) -> Set<Message.ID> {
        guard let latest = messages.last, !latestFolded else { return expanded }
        return expanded.union([latest.id])
    }

    /// The runs to show for `messages` (in the order shown), in that order: each open one
    /// alone, the folded ones next to each other together.
    static func runs(_ messages: [Message], expanded: Set<Message.ID>) -> [[Message]] {
        var runs: [[Message]] = []
        for message in messages {
            if expanded.contains(message.id) || runs.last.map({ expanded.contains($0[0].id) }) ?? true {
                runs.append([message])
            } else {
                runs[runs.count - 1].append(message)
            }
        }
        return runs
    }
}
