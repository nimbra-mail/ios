import Foundation
import NimbraCore

/// Blocking senders, as the Mac does (`labels.rs`, the engine's `blocking.rs`): the address
/// on the account's list, their threads in the Blocked label, their mail never notifying.
/// The toast's Undo puts it all back.
extension AppModel {
    /// The account's blocked addresses. Disk.
    func loadBlocked(_ account: Account.ID) async {
        if let list = await engine(for: account, work: { try $0.blockedSenders(accountId: account) }) {
            blockedSenders[account] = list.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        }
    }

    /// Every account's blocked addresses. Disk.
    func loadAllBlocked() async {
        for account in accounts { await loadBlocked(account.id) }
    }

    /// Whether the thread is in the Blocked label (its sender blocked): the ⋯ menu then
    /// offers Unblock sender.
    func isBlocked(_ id: MailThread.ID) -> Bool {
        thread(id)?.labels.contains { $0 == Self.blockedLabel || $0.hasSuffix("/\(Self.blockedLabel)") } ?? false
    }

    /// Who wrote the thread, to block: the sender its row names (`senderAddress`), else the
    /// latest message from someone other than the account, its messages read first when
    /// they are not yet. Disk or network.
    func sender(of id: MailThread.ID) async -> Person? {
        let own = account(id.account)?.email.lowercased()
        if let sender = thread(id)?.sender, !sender.email.isEmpty, sender.email.lowercased() != own { return sender }
        if thread(id)?.messages.isEmpty ?? true { await loadMessages(id) }
        let messages = thread(id)?.messages ?? []
        return messages.last { !$0.from.email.isEmpty && $0.from.email.lowercased() != own }?.from
    }

    /// Blocks the thread's sender: it leaves every listing at once for the Blocked label,
    /// and a toast says so with Undo. Network.
    func blockSender(of id: MailThread.ID) async {
        guard let person = await sender(of: id) else {
            alert = .invalid(String(localized: "That sender has no address to block."))
            return
        }
        let from = source(of: id)
        let before = (listings, opened, searchResults)
        remove(id)
        let done: Void? = await engine(for: id.account, report: true) {
            try $0.blockSender(accountId: id.account, address: person.email, threadId: id.thread, from: from)
        }
        guard done != nil else {
            (listings, opened, searchResults) = before
            return
        }
        reached(id.account)
        await loadBlocked(id.account)
        let name = person.name.isEmpty ? person.email : person.name
        // Six seconds, as the Mac's Undo pill.
        show(Toast(icon: .ban, text: String(localized: "\(name) is blocked."), duration: .seconds(6))) { [weak self] in
            await self?.undoBlock(person.email, of: id)
        }
    }

    /// Undo on the Blocked toast: the sender off the list, and the thread out of Blocked
    /// and back in the inbox. Network.
    func undoBlock(_ address: String, of id: MailThread.ID) async {
        await unblock(address, in: id.account, thread: id.thread)
    }

    /// Unblocks the thread's sender: off the list, and the thread out of Blocked and back
    /// in the inbox. Network.
    func unblockSender(of id: MailThread.ID) async {
        guard let person = await sender(of: id) else { return }
        await unblock(person.email, in: id.account, thread: id.thread)
        let name = person.name.isEmpty ? person.email : person.name
        show(Toast(icon: .ban, text: String(localized: "\(name) is unblocked.")))
    }

    /// Takes an address off the account's list (Blocked senders), and the thread, when
    /// there is one, back to the inbox. Network with a thread, else disk.
    func unblock(_ address: String, in account: Account.ID, thread: String? = nil) async {
        let before = blockedSenders[account]
        blockedSenders[account]?.removeAll { $0.caseInsensitiveCompare(address) == .orderedSame }
        let done: Void? = await engine(for: account, report: true) {
            try $0.unblockSender(accountId: account, address: address, threadId: thread)
        }
        guard done != nil else {
            blockedSenders[account] = before
            return
        }
        if thread != nil {
            reached(account)
            await showInbox()
        }
    }

    /// The label blocked senders' mail goes to (made by the engine when there is none).
    nonisolated static let blockedLabel = "Blocked"
}
