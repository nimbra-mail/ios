import NimbraCore
import SwiftUI

/// A thread in a mailbox's list: the kit's Thread Row as that mailbox shows it, opening the
/// thread (a draft opens in the composer), with the Mac's row actions in its context menu.
struct MailboxThreadLink: View {
    let thread: MailThread
    let mailbox: Mailbox
    let isAllInboxes: Bool
    /// The Labels sheet, presented by the list.
    @Binding var labelling: LabelRequest?
    /// Delete forever, asked first by the list (`deletesForever`).
    @Binding var deleting: MailThread.ID?
    @Environment(AppModel.self) private var app
    @Environment(\.openURL) private var openURL

    var body: some View {
        Group {
            if mailbox == .drafts {
                // A draft opens in the composer (Compose's `openDraft`).
                Button { Task { await app.openDraft(thread: thread.id) } } label: { row }
            } else {
                NavigationLink(value: thread.id) { row }
            }
        }
        .buttonStyle(.plain)
        .contextMenu { menu }
    }

    private var row: some View {
        ThreadRow(
            thread: thread,
            pill: pill,
            showsLabel: !isLabelList,
            time: wakeTime,
            placeholder: app.account(thread.id.account)?.person,
            inDrafts: mailbox == .drafts
        )
    }

    /// All inboxes tags each row with its account; Drafts marks each a draft.
    private var pill: (name: String, dot: Color)? {
        if isAllInboxes, let account = app.account(thread.id.account) {
            return (account.name, account.person.tone.dot)
        }
        if mailbox == .drafts { return (String(localized: "Draft"), .accentRose) }
        return nil
    }

    private var isLabelList: Bool {
        if case .label = mailbox { true } else { false }
    }

    /// When a snoozed thread or reminder comes back: "Fri 8:00 AM".
    private var wakeTime: String? {
        guard mailbox == .snoozed || mailbox == .reminders, let date = app.wakeTime(thread.id) else { return nil }
        return Calendar.current.isDateInToday(date)
            ? date.formatted(date: .omitted, time: .shortened)
            : date.formatted(.dateTime.weekday(.abbreviated).hour().minute())
    }

    @ViewBuilder
    private var menu: some View {
        let id = thread.id
        Button(thread.isUnread ? "Mark as read" : "Mark as unread") {
            Task { thread.isUnread ? await app.markRead(id) : await app.markUnread(id) }
        }
        Button(thread.isStarred ? "Remove star" : "Star") {
            Task { await app.toggleStar(id) }
        }
        if mailbox.isInboxLike || isAllInboxes {
            Button("Mark done") { Task { await app.markDone(id) } }
        } else if mailbox.restoringAction != nil {
            Button("Move to inbox") { Task { await app.moveToInbox(id) } }
        }
        Button("Label…") { labelling = LabelRequest(thread: id, mode: .label) }
        Button("Move to…") { labelling = LabelRequest(thread: id, mode: .move) }
        Divider()
        if mailbox == .trash {
            Button("Delete forever", role: .destructive) { deleting = id }
        } else {
            Button("Move to trash", role: .destructive) { Task { await app.trash(id) } }
        }
        if mailbox != .spam, mailbox != .trash {
            Button("Report spam", role: .destructive) { Task { await app.reportSpam(id) } }
        }
        if let gmail = app.gmailURL(for: id) {
            Divider()
            Button("Open in Gmail") { openURL(gmail) }
        }
    }
}
