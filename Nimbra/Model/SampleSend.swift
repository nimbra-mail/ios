import Foundation
import NimbraCore
import Synchronization

/// A message on its way on `SampleEngine` (and in the tests): held until it is delivered
/// or taken back, with the outcome it was given. Nothing leaves the device.
nonisolated final class SampleSend: OutgoingSend, @unchecked Sendable {
    private struct State {
        var stage: SendStage = .held
        var deliveries = 0
    }

    private let account: String
    private let outgoing: OutgoingMessage
    private let at: Int64
    private let outcome: @Sendable () -> SendOutcome
    private let state = Mutex(State())

    init(account: String, message: OutgoingMessage, deliverAtMs: Int64, outcome: @escaping @Sendable () -> SendOutcome) {
        self.account = account
        outgoing = message
        at = deliverAtMs
        self.outcome = outcome
        super.init(noHandle: NoHandle())
    }

    required init(unsafeFromHandle handle: UInt64) {
        fatalError("A sample send has no engine handle.")
    }

    /// How often it was handed over.
    var deliveries: Int { state.withLock { $0.deliveries } }

    override func accountId() -> String { account }
    override func deliverAtMs() -> Int64 { at }
    override func isKept() -> Bool { true }
    override func message() -> OutgoingMessage { outgoing }
    override func subject() -> String { outgoing.subject }
    override func stage() -> SendStage { state.withLock { $0.stage } }

    override func deliver() -> SendOutcome {
        let waiting = state.withLock { state in
            guard state.stage == .held else { return false }
            state.stage = .out
            state.deliveries += 1
            return true
        }
        guard waiting else { return .notWaiting }
        let result = outcome()
        state.withLock { state in
            state.stage = switch result {
            case .waitingForConnection: .held
            case .refused: .refused
            case .maybeSent: .unsure
            default: .over
            }
        }
        return result
    }

    override func undo() -> Bool {
        state.withLock { state in
            guard state.stage == .held || state.stage == .refused else { return false }
            state.stage = .over
            return true
        }
    }

    override func saveToDrafts() -> String? {
        state.withLock { $0.stage = .over }
        return "draft-\(UUID().uuidString)"
    }

    override func discard() -> Bool {
        state.withLock { $0.stage = .over }
        return true
    }
}
