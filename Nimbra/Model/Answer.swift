import NimbraCore

/// How a thread is answered: the Thread screen's Reply, Reply all and Forward.
nonisolated enum Answer: Hashable, Sendable {
    case reply, replyAll, forward

    var kind: AnswerKind {
        switch self {
        case .reply: .reply
        case .replyAll: .replyAll
        case .forward: .forward
        }
    }
}
