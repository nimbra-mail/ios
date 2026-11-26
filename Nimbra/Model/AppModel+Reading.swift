import Foundation
import NimbraCore

/// Reading: a thread's messages, from the device when it keeps them, else from the
/// server; and search. The Reading and Search features build on these.
extension AppModel {
    /// Reads a thread's messages into `opened`: what the device keeps at once, else from
    /// the server. Network when they are not kept.
    func loadMessages(_ id: MailThread.ID) async {
        guard let summary = thread(id) else { return }
        let read = await engine(for: id.account, report: true) { engine in
            try engine.cachedThread(accountId: id.account, threadId: id.thread)
                ?? engine.readThread(accountId: id.account, threadId: id.thread)
        }
        guard let read else { return }
        var thread = opened[id] ?? summary
        thread.messages = read.messages.map(Message.init)
        if let latest = thread.messages.last { thread.sender = latest.from }
        opened[id] = thread
    }

    /// Searches the account shown (Gmail's search words, or text for an account with its
    /// own servers). Network.
    func search(_ query: String) async {
        let query = query.trimmingCharacters(in: .whitespaces)
        guard let account = accountID, !query.isEmpty else {
            searchResults = []
            return
        }
        let names = labelNames(account)
        guard let page = await engine(for: account, work: { try $0.search(accountId: account, query: query, page: nil, limit: 30) }) else { return }
        searchResults = page.threads.map { MailThread(row: $0, account: account, labelNames: names) }
    }
}
