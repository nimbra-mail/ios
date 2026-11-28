import Foundation
import NimbraCore

/// Labels (IMAP: folders): an account's list, made, renamed and deleted, put on a thread and
/// taken off (15 · Labels), and Move to. Each change shows at once and is put back when the
/// engine refuses it, as the Mac's `labels.rs` does.
extension AppModel {
    /// The account's labels, in the engine's order (Gmail's sorted by name).
    func labels(_ account: Account.ID?) -> [MailLabel] {
        guard let account else { return [] }
        var index = 0
        return (mailboxes[account] ?? []).compactMap { entry in
            guard entry.section == .labels, case .label(let id) = entry.mailbox else { return nil }
            defer { index += 1 }
            return MailLabel(id: id, name: entry.name ?? id, index: index)
        }
    }

    /// The labels a thread has, by id (its rows carry their names).
    func labelIDs(of id: MailThread.ID) -> Set<String> {
        let names = Set(thread(id)?.labels ?? [])
        return Set(labels(id.account).filter { names.contains($0.name) }.map(\.id))
    }

    /// The account's labels fetched again, then its list of mailboxes. Network.
    func refreshLabels(_ account: Account.ID) async {
        let boxes = await engine(for: account) { engine -> [MailboxEntry] in
            _ = try engine.labels(accountId: account)
            return try engine.mailboxes(accountId: account)
        }
        guard let boxes else { return }
        reached(account)
        mailboxes[account] = boxes
    }

    /// A new label, unless one is called that already (in any case): then that one. A blank
    /// name makes none. Network.
    @discardableResult
    func createLabel(_ name: String, in account: Account.ID) async -> MailLabel? {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        if let known = labels(account).first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            return known
        }
        guard let made = await engine(for: account, report: true, work: { try $0.createLabel(accountId: account, name: name) }) else { return nil }
        reached(account)
        await loadMailboxes(account)
        show(Toast(icon: .tag, text: String(localized: "Created “\(made.name)”.")))
        return labels(account).first { $0.id == made.id } ?? MailLabel(id: made.id, name: made.name, index: 0)
    }

    /// Renames a label, here and on the server. Network.
    func renameLabel(_ label: MailLabel, to name: String, in account: Account.ID) async {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name != label.name else { return }
        let done: Void? = await engine(for: account, report: true) {
            try $0.renameLabel(accountId: account, labelId: label.id, name: name)
        }
        guard done != nil else { return }
        reached(account)
        await loadMailboxes(account)
        renameOnThreads(label.name, to: name, in: account)
    }

    /// Deletes a label; the mail it was on stays. One already gone counts as deleted.
    /// Network.
    func deleteLabel(_ label: MailLabel, in account: Account.ID) async {
        let done: Void? = await engine(for: account, report: true) { engine in
            do {
                try engine.deleteLabel(accountId: account, labelId: label.id)
            } catch NimbraError.NotFound {
                // Already gone: what was asked is done.
            }
        }
        guard done != nil else { return }
        reached(account)
        await loadMailboxes(account)
        listings[ListingKey(account: account, mailbox: .label(id: label.id))] = nil
        renameOnThreads(label.name, to: nil, in: account)
        show(Toast(icon: .tag, text: String(localized: "Label deleted. The mail it was on is still there.")))
    }

    /// Puts a label on a thread, or takes it off. Network.
    func toggleLabel(_ label: MailLabel, on id: MailThread.ID) async {
        let has = labelIDs(of: id).contains(label.id)
        let before = (listings, opened, searchResults)
        update(id) { thread in
            if has { thread.labels.removeAll { $0 == label.name } } else { thread.labels.append(label.name) }
        }
        if has { listings[ListingKey(account: id.account, mailbox: .label(id: label.id))]?.threads.removeAll { $0.id == id } }
        let done: Void? = await engine(for: id.account, report: true) {
            try $0.relabel(accountId: id.account, threadId: id.thread, add: has ? [] : [label.id], remove: has ? [label.id] : [])
        }
        if done == nil { (listings, opened, searchResults) = before } else { reached(id.account) }
    }

    /// Move to a label: the label added and, from an inbox (the account's, a Split Inbox
    /// category, All inboxes), out of it. Network.
    func move(_ id: MailThread.ID, to label: MailLabel) async {
        let from = source(of: id)
        let before = (listings, opened, searchResults)
        update(id) { thread in
            if !thread.labels.contains(label.name) { thread.labels.append(label.name) }
        }
        if from.isInboxLike { removeFromInboxes(id) }
        let done: Void? = await engine(for: id.account, report: true) {
            try $0.moveToLabel(accountId: id.account, threadId: id.thread, labelId: label.id, from: from)
        }
        guard done != nil else {
            (listings, opened, searchResults) = before
            return
        }
        reached(id.account)
        show(Toast(icon: .folder, text: String(localized: "Moved to “\(label.name)”.")))
    }

    /// The mailbox a thread is shown from, as the engine wants it for a move: an inbox when
    /// one lists it, else the first listing that has it, else All Mail.
    func source(of id: MailThread.ID) -> Mailbox {
        let holding = listings.filter { $0.value.threads.contains { $0.id == id } }.map(\.key)
        if holding.contains(where: { $0.mailbox.isInboxLike }) { return .inbox }
        return holding.first(where: { $0.account == id.account })?.mailbox ?? .allMail
    }

    /// Takes a thread out of the account's inboxes and All inboxes (a move, Done).
    func removeFromInboxes(_ id: MailThread.ID) {
        for key in listings.keys where (key.account == id.account || key.isEveryAccount) && key.mailbox.isInboxLike {
            listings[key]?.threads.removeAll { $0.id == id }
        }
    }

    /// A label renamed (or gone, with nil) on every thread of the account shown.
    private func renameOnThreads(_ old: String, to new: String?, in account: Account.ID) {
        for key in listings.keys where key.account == account || key.isEveryAccount {
            guard let threads = listings[key]?.threads else { continue }
            listings[key]?.threads = threads.map { thread in
                guard thread.id.account == account else { return thread }
                var thread = thread
                thread.labels = thread.labels.compactMap { $0 == old ? new : $0 }
                return thread
            }
        }
    }
}
