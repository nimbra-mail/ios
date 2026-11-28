import Foundation
import NimbraCore
import Synchronization

/// The sample engine's preferences and signatures, kept in memory as the engine keeps them
/// on disk: the defaults the Mac starts with, and two signatures for the work account.
nonisolated struct SampleSettings {
    var preferences = Preferences.standard
    var signatures: [SignatureInfo] = [
        SignatureInfo(
            id: "sample-signature-work", accountId: SampleData.work.id, name: "Work",
            html: "<div>Luan Gjokaj</div><div>UX Engineer &amp; Designer</div><div><a href=\"https://nimbra.me\">nimbra.me</a></div>",
            isDefault: true
        ),
        SignatureInfo(id: "sample-signature-short", accountId: SampleData.work.id, name: "Short", html: "<div>Luan</div>", isDefault: false),
    ]
    var nextID = 1
}

nonisolated extension Preferences {
    /// What the engine starts with (`nimbra-core`'s `settings.rs`), as on the Mac.
    static let standard = Preferences(
        notifications: true, originalView: true, loadImages: true, darkEmails: true, markRead: .open,
        checkEverySeconds: 30, undoSendSeconds: 6, quoteReplies: true, badge: true, notificationSound: true,
        newestFirst: false, subjectOwnLine: true, textSize: .default
    )
}

nonisolated extension SampleEngine {
    func preferences() -> Preferences { settings.withLock { $0.preferences } }

    func setPreferences(preferences: Preferences) throws {
        settings.withLock { $0.preferences = preferences }
    }

    /// The sample mail is not kept on the device: there is nothing to clear.
    func clearKeptMail() {}

    func signatures(accountId: String) -> [SignatureInfo] {
        settings.withLock { $0.signatures.filter { $0.accountId == accountId } }
    }

    func addSignature(accountId: String) throws -> String {
        guard accounts().contains(where: { $0.id == accountId }) else { throw NimbraError.Invalid(message: "There is no such account here.") }
        return settings.withLock { state in
            let id = "sample-signature-\(state.nextID)"
            state.nextID += 1
            let count = state.signatures.count { $0.accountId == accountId }
            state.signatures.append(SignatureInfo(
                id: id, accountId: accountId, name: count == 0 ? "Signature" : "Signature \(count + 1)", html: "", isDefault: count == 0
            ))
            return id
        }
    }

    func updateSignature(signatureId: String, name: String, html: String) throws {
        try settings.withLock { state in
            guard let index = state.signatures.firstIndex(where: { $0.id == signatureId }) else { throw NimbraError.NotFound }
            state.signatures[index].name = name
            state.signatures[index].html = html
        }
    }

    func deleteSignature(signatureId: String) throws {
        settings.withLock { state in
            guard let index = state.signatures.firstIndex(where: { $0.id == signatureId }) else { return }
            let removed = state.signatures.remove(at: index)
            // As the engine does: the default falls back to the account's first.
            if removed.isDefault, let first = state.signatures.firstIndex(where: { $0.accountId == removed.accountId }) {
                state.signatures[first].isDefault = true
            }
        }
    }

    func setDefaultSignature(accountId: String, signatureId: String?) throws {
        settings.withLock { state in
            for index in state.signatures.indices where state.signatures[index].accountId == accountId {
                state.signatures[index].isDefault = state.signatures[index].id == signatureId
            }
        }
    }
}
