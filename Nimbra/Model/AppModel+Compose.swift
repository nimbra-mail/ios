import Foundation
import NimbraCore

/// Writing: a new message, an answer (Reply, Reply all, Forward), a saved draft or a
/// `mailto:` link opens the composer (`composer`, presented by the root view). Drafts
/// save themselves once typing pauses, as on the Mac. Sending is `AppModel+Sending`.
///
/// What other areas call is in `AppModel+ComposeHooks`.
extension AppModel {
    /// The account a new message is from: the one the inbox shows, else the default.
    var defaultFrom: Account.ID? {
        accountID ?? accounts.first(where: \.isDefault)?.id ?? accounts.first?.id
    }

    // MARK: Opening (`compose`, `startAnswer`, `openDraft`, `openMailto` are in
    // `AppModel+ComposeHooks`)

    /// Shows a composer; one that was open is kept as a draft.
    func present(_ composer: Composer) {
        if let open = self.composer, open.id != composer.id {
            // One composer at a time: what was open is kept as a draft.
            close(open)
        }
        self.composer = composer
    }

    // MARK: Closing

    /// The composer, for the root view's sheet: swiping it away closes it, and what was
    /// written is saved to Drafts.
    var presentedComposer: Composer? {
        get { composer }
        set {
            if let newValue {
                composer = newValue
            } else if let composer {
                close(composer)
            }
        }
    }

    /// Closes the composer; what was written is still saved to Drafts.
    func close(_ composer: Composer) {
        if self.composer?.id == composer.id { self.composer = nil }
        draftSaves.removeValue(forKey: composer.id)?.cancel()
        guard composer.isDirty, composer.hasContent, !composer.isSending else { return }
        Task { await saveDraft(composer) }
    }

    /// Closes the composer and deletes its draft.
    func discard(_ composer: Composer) {
        if self.composer?.id == composer.id { self.composer = nil }
        draftSaves.removeValue(forKey: composer.id)?.cancel()
        composer.resave = false
        Task {
            // A save that is out finishes first, so its draft is the one deleted.
            while composer.isSaving { try? await clock.sleep(.milliseconds(200)) }
            guard let draft = composer.draftID else { return }
            let account = composer.from
            await engine(for: account) { try $0.deleteDraft(accountId: account, draftId: draft) }
        }
    }

    // MARK: Drafts that save themselves

    /// Something in the composer changed: its draft is saved once typing pauses (longer
    /// with attachments, which make every save an upload), as on the Mac.
    func composerChanged(_ composer: Composer) {
        composer.changed()
        composer.notice = nil
        let pause: Duration = composer.files.isEmpty && composer.kept.isEmpty ? .milliseconds(2500) : .seconds(10)
        draftSaves[composer.id]?.cancel()
        draftSaves[composer.id] = Task { [clock] in
            do { try await clock.sleep(pause) } catch { return }
            await self.saveDraft(composer)
        }
    }

    /// Saves the composer's message to its account's Drafts, new or over its draft.
    /// `explicit` saves even what has not changed (Send later needs the draft).
    func saveDraft(_ composer: Composer, explicit: Bool = false) async {
        guard !composer.isSending else { return }
        if composer.isSaving {
            composer.resave = true
            return
        }
        guard explicit || (composer.isDirty && composer.hasContent) else { return }
        composer.isSaving = true
        composer.resave = false
        let account = composer.from
        let message = composer.outgoing
        let draftID = composer.draftID
        let edits = composer.edits
        let saved = await engine(for: account) {
            try $0.saveDraft(accountId: account, draftId: draftID, message: message)
        }
        composer.isSaving = false
        if let saved {
            reached(account)
            if composer.from != account {
                // From changed while it was saving: that draft is in the other account's
                // Drafts. Delete it there; the next save is from the account picked.
                Task { await engine(for: account) { try $0.deleteDraft(accountId: account, draftId: saved) } }
                composer.draftID = nil
                composer.resave = true
            } else {
                composer.draftID = saved
                composer.savedEdits = max(composer.savedEdits, edits)
            }
        }
        if composer.resave, !composer.isSending {
            await saveDraft(composer)
        }
    }

    // MARK: From and the signature

    /// Sends the message from another account (From), with that account's default
    /// signature when it had its old account's default.
    func setFrom(_ account: Account.ID, for composer: Composer) async {
        guard composer.from != account else { return }
        let old = composer.from
        let oldDefault = await defaultSignature(for: old)
        composer.from = account
        if composer.signature == nil || composer.signature?.id == oldDefault?.id {
            composer.signature = await defaultSignature(for: account)
        }
        if let draft = composer.draftID, !composer.isSaving {
            // Its draft moves with it: out of the old account's Drafts.
            composer.draftID = nil
            Task { await engine(for: old) { try $0.deleteDraft(accountId: old, draftId: draft) } }
        }
        composerChanged(composer)
    }

    /// The account's signatures (Settings makes them). Disk.
    func signatures(for account: Account.ID) async -> [SignatureInfo] {
        await engine(for: account) { $0.signatures(accountId: account) } ?? []
    }

    func setSignature(_ signature: SignatureInfo?, for composer: Composer) {
        composer.signature = signature.map { Composer.Signature(id: $0.id, html: $0.html) }
        if signature == nil { composer.signatureText = "" }
        composerChanged(composer)
    }

    func defaultSignature(for account: Account.ID) async -> Composer.Signature? {
        await signatures(for: account).first(where: \.isDefault).map { Composer.Signature(id: $0.id, html: $0.html) }
    }

    // MARK: Addresses

    /// Who to suggest for what is typed in a field, best first: never the user's own
    /// addresses nor anyone already in the message. Disk.
    func suggestions(for query: String, in composer: Composer) async -> [Person] {
        let query = query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return [] }
        let account = composer.from
        let present = composer.present
        let found = await engine(for: account) {
            try $0.suggestContacts(accountId: account, query: query, present: present)
        } ?? []
        return found.prefix(5).map(Person.init)
    }

    // MARK: Attachments

    /// Attachments can be 25 MB in total (the engine refuses more when sending: its
    /// `ATTACHMENT_LIMIT`, which the FFI does not export).
    static let attachmentLimit: Int64 = 25 * 1024 * 1024

    /// Attaches files, unless they would go over the limit: then nothing is attached and
    /// the composer says so.
    func attach(_ files: [Composer.File], to composer: Composer) {
        let adding = files.reduce(Int64(0)) { $0 + Int64($1.bytes.count) }
        guard composer.attachmentBytes + adding <= Self.attachmentLimit else {
            composer.notice = String(localized: "Attachments can be 25 MB in total.")
            return
        }
        composer.files += files
        composerChanged(composer)
    }

    func removeFile(_ id: Composer.File.ID, from composer: Composer) {
        composer.files.removeAll { $0.id == id }
        composerChanged(composer)
    }

    func removeKept(_ attachment: AttachmentInfo, from composer: Composer) {
        composer.kept.removeAll { $0 == attachment }
        composerChanged(composer)
    }
}

extension Answer {
    var composerKind: Composer.Kind {
        switch self {
        case .reply: .reply
        case .replyAll: .replyAll
        case .forward: .forward
        }
    }
}
