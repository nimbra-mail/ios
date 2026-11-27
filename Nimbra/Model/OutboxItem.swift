import Foundation
import NimbraCore

/// A message sent from the composer, on its way: held for the undo time, then handed to
/// the server. It keeps the composer, so Undo send brings back what was written.
struct OutboxItem: Identifiable {
    nonisolated enum Stage: Equatable, Sendable {
        /// In its undo time: Undo takes it back.
        case held
        /// Handed to the server.
        case delivering
    }

    let id = UUID()
    let send: OutgoingSend
    let composer: Composer
    var stage: Stage = .held

    var account: Account.ID { composer.from }
}
