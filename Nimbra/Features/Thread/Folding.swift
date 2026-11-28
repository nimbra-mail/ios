/// How a thread's earlier messages show under its subject: oldest first and the latest last,
/// as the Mac shows a conversation; folded ones together in a card, each opened one on its own.
nonisolated enum Folding {
    /// The runs to show for `earlier` (oldest first, the latest left out), in that order.
    static func runs(_ earlier: [Message], expanded: Set<Message.ID>) -> [[Message]] {
        var runs: [[Message]] = []
        for message in earlier {
            if expanded.contains(message.id) || runs.last.map({ expanded.contains($0[0].id) }) ?? true {
                runs.append([message])
            } else {
                runs[runs.count - 1].append(message)
            }
        }
        return runs
    }
}
