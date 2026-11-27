import Foundation
import NimbraCore

/// Reading: a thread's messages, from the device when it keeps them, else from the
/// server. Search is `AppModel+Search`.
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
}
