import NimbraCore

/// How a thread is answered.
nonisolated enum Answer: Hashable, Sendable {
    case reply
    case replyAll
    case forward

    /// The engine's kind of answer.
    var kind: AnswerKind {
        switch self {
        case .reply: .reply
        case .replyAll: .replyAll
        case .forward: .forward
        }
    }
}
