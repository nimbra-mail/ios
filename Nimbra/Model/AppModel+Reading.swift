import Foundation
import NimbraCore

/// Reading: a thread's messages, from the device when it keeps them, else from the
/// server; when it counts as read; its files and remote images. Search is
/// `AppModel+Search`. The Thread screen builds on these.
extension AppModel {
    /// Opens a thread: Preferences again, its messages, and marking it read when
    /// `markReadAfter` says (cancelled with the task, when the thread is left before then).
    func open(_ id: MailThread.ID) async {
        keptUnread.remove(id)
        await loadReadingOptions()
        async let messages: Void = loadMessages(id)
        await markReadWhenDue(id)
        await messages
    }

    /// Preferences as reading follows them. Disk.
    func loadReadingOptions() async {
        let read = await engine { ReadingOptions($0.preferences(), markReadAfterMs: $0.markReadAfterMs()) }
        if let read { readingOptions = read }
    }

    /// Marks an opened thread read at once, after the delay, or never, as Preferences say;
    /// not when it was left (cancelled) or marked unread meanwhile.
    func markReadWhenDue(_ id: MailThread.ID) async {
        guard let after = readingOptions.markReadAfter else { return }
        if after > .zero {
            do { try await readingSleep(after) } catch { return }
        }
        guard !Task.isCancelled, !keptUnread.contains(id) else { return }
        await markRead(id)
    }

    /// Mark as unread from the open thread: it stays unread while it is open.
    func keepUnread(_ id: MailThread.ID) async {
        keptUnread.insert(id)
        await markUnread(id)
    }

    /// Reads a thread's messages into `opened`: what the device keeps at once, else from
    /// the server. Network when they are not kept. A failure is shown in the thread
    /// (`unreadable`), not in an alert.
    func loadMessages(_ id: MailThread.ID) async {
        guard let summary = thread(id) else { return }
        unreadable.remove(id)
        let read = await engine(for: id.account) { engine in
            try engine.cachedThread(accountId: id.account, threadId: id.thread)
                ?? engine.readThread(accountId: id.account, threadId: id.thread)
        }
        guard let read, !read.messages.isEmpty else {
            if opened[id]?.messages.isEmpty ?? true { unreadable.insert(id) }
            return
        }
        var thread = opened[id] ?? summary
        thread.messages = read.messages.map(Message.init)
        thread.messageCount = thread.messages.count
        if let latest = thread.messages.last { thread.sender = latest.from }
        opened[id] = thread
    }

    // MARK: Showing a message

    /// Whether a message shows its HTML in the web view (else the reader).
    func showsOriginal(_ message: Message) -> Bool {
        guard message.html != nil else { return false }
        return readingOptions.originalView != otherView.contains(message.id)
    }

    /// Switches one message between its original formatting and the reader.
    func switchView(_ message: Message) {
        if otherView.contains(message.id) { otherView.remove(message.id) } else { otherView.insert(message.id) }
    }

    /// Whether a message's remote images load: the original view follows Preferences, the
    /// reader asks every time, as on the Mac. "Load images" allows them for the session.
    func loadsImages(_ message: Message) -> Bool {
        imagesAllowed.contains(message.id) || (showsOriginal(message) && readingOptions.loadImages)
    }

    /// One remote image, through the engine (https on a public host only), kept for the
    /// session. Network. Nil when it cannot be had.
    func remoteImage(_ url: String) async -> Data? {
        if let kept = remoteImages[url] { return kept }
        guard let data = await engine(work: { try $0.fetchRemoteImage(url: url) }) else { return nil }
        // A session's worth: an inbox of newsletters, not every image ever shown.
        if remoteImages.count >= 200 { remoteImages.removeAll() }
        remoteImages[url] = data
        return data
    }

    // MARK: Files

    /// Downloads an attachment into a protected file of its own for Quick Look and sharing
    /// (`AttachmentFiles`). Network. Nil when it failed (said in an alert).
    func attachmentFile(_ attachment: Attachment, in thread: MailThread.ID) async -> URL? {
        let data = await engine(for: thread.account, report: true) {
            try $0.downloadAttachment(accountId: thread.account, messageId: attachment.messageID, attachmentId: attachment.attachmentID)
        }
        guard let data else { return nil }
        reached(thread.account)
        do {
            return try AttachmentFiles.write(data, named: attachment.name, for: thread)
        } catch {
            alert = .failed(String(localized: "The attachment could not be opened."))
            return nil
        }
    }

    // MARK: Actions from the thread

    /// Done from the open thread: archived, with Undo.
    @discardableResult
    func markDoneFromThread(_ id: MailThread.ID) async -> Removal? {
        await removeUndoably(id, .done, message: String(localized: "Marked done"))
    }

    /// Moves a thread to Trash, with Undo; it leaves the open mailbox.
    @discardableResult
    func trash(_ id: MailThread.ID) async -> Removal? {
        await removeUndoably(id, .trash, message: String(localized: "Moved to trash"))
    }

    /// The mailbox a thread is listed in, other than an inbox, Starred or a split
    /// category: where Move to Inbox applies. Nil when it is in an inbox.
    func outsideInbox(_ id: MailThread.ID) -> Mailbox? {
        let keys = listings.filter { $0.value.threads.contains { $0.id == id } }.map(\.key.mailbox)
        let inInbox = keys.contains { mailbox in
            if case .split = mailbox { return true }
            return mailbox == .inbox
        }
        guard !inInbox else { return nil }
        return keys.first { $0 != .starred && $0 != .important }
    }

    /// Back into the inbox, with Undo: restored from Trash, not spam from Spam, else out of
    /// the archive.
    @discardableResult
    func moveToInbox(_ id: MailThread.ID) async -> Removal? {
        switch outsideInbox(id) {
        case .trash: await removeUndoably(id, .untrash, message: String(localized: "Restored"))
        case .spam: await removeUndoably(id, .notSpam, message: String(localized: "Moved to inbox"))
        default: await removeUndoably(id, .moveToInbox, message: String(localized: "Moved to inbox"))
        }
    }

    /// A thread taken out of the listings by an action, and how to put it back.
    struct Removal {
        let id: MailThread.ID
        /// The engine's inverse (`undoAction`): Undo after Done is Move to Inbox.
        let inverse: ThreadAction
        /// Where it was listed, to show it there again at once.
        let places: [(key: ListingKey, index: Int, thread: MailThread)]
    }

    /// Applies an action that takes the thread out, then offers Undo in a toast, as the
    /// Mac does. Nil when the engine refused it or it has no inverse.
    private func removeUndoably(_ id: MailThread.ID, _ action: ThreadAction, message: String) async -> Removal? {
        let places = listings.compactMap { key, listing in
            listing.threads.firstIndex { $0.id == id }.map { (key: key, index: $0, thread: listing.threads[$0]) }
        }
        guard await act(id, action, removes: true) != nil, let inverse = undoAction(action: action) else { return nil }
        let removal = Removal(id: id, inverse: inverse, places: places)
        show(Toast(icon: .done, text: message)) { [weak self] in await self?.undo(removal) }
        return removal
    }

    /// Undo: the thread is listed where it was at once, and the engine makes the inverse
    /// (queued while offline). Refused, it is taken out again.
    func undo(_ removal: Removal) async {
        for place in removal.places where listings[place.key]?.threads.contains(where: { $0.id == removal.id }) == false {
            let threads = listings[place.key]?.threads ?? []
            listings[place.key]?.threads.insert(place.thread, at: min(place.index, threads.count))
        }
        if await act(removal.id, removal.inverse) == nil { remove(removal.id) }
    }
}
