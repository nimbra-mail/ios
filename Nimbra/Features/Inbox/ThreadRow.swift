import SwiftUI

/// The kit's Thread Row: avatar, sender, count and label, time, then the subject on its
/// own line and two lines of the latest message (Subject=Own line), or the subject and the
/// start of the message side by side on one line (Subject=Beside), as Settings › Appearance
/// › Subject on its own line says.
struct ThreadRow: View {
    let thread: MailThread
    @Environment(AppModel.self) private var app
    // MARK: Mailboxes
    /// The pill after the sender instead of the first label: the account in All inboxes,
    /// "Draft" in Drafts. Nil keeps the label.
    var pill: (name: String, dot: Color)?
    /// Whether a label's pill shows (not inside that label's own list).
    var showsLabel = true
    /// The time shown instead of the thread's (when a snooze or reminder comes back).
    var time: String?
    /// The avatar the row shows when it names no one (the account's, for a draft to no
    /// one yet).
    var placeholder: Person?
    /// In Drafts, a row that names no one says "Draft"; elsewhere "Unknown sender".
    var inDrafts = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let sender = namedSender ?? placeholder {
                AvatarView(person: sender, size: 40)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(verbatim: senderName)
                        .nimbraText(.sender)
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)
                    if thread.messageCount > 1 {
                        Text(thread.messageCount, format: .number)
                            .nimbraText(.caption)
                            .foregroundStyle(Color.textTertiary)
                    }
                    if let pill, !(inDrafts && namedSender == nil) {
                        // A draft to no one already says "Draft" in place of the sender.
                        LabelPill(name: pill.name, dot: pill.dot)
                    } else if showsLabel, let label = thread.labels.first {
                        LabelPill(name: label)
                    }
                    Spacer(minLength: 4)
                    Text(verbatim: time ?? MailDate.short(thread.snoozedUntil ?? thread.date))
                        .nimbraText(.footnote)
                        .foregroundStyle(Color.textTertiary)
                }
                if app.preferences.subjectOwnLine {
                    subject
                    snippet.lineLimit(2)
                } else {
                    HStack(spacing: 6) {
                        subject
                            // At most 200 pt, so the start of the message shows after it.
                            .frame(maxWidth: 200, alignment: .leading)
                            .fixedSize(horizontal: true, vertical: false)
                        snippet.lineLimit(1)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .overlay(alignment: .topLeading) {
            if thread.isUnread {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 7, height: 7)
                    .offset(x: 7, y: 29)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityValue(thread.isUnread ? Text("Unread") : Text(verbatim: ""))
    }

    private var subject: some View {
        Text(verbatim: thread.shownSubject)
            .nimbraText(.subheadMedium)
            .foregroundStyle(Color.textPrimary)
            .lineLimit(1)
    }

    private var snippet: some View {
        Text(verbatim: thread.snippet)
            .nimbraText(.subhead)
            .foregroundStyle(Color.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The sender, unless the row names no one (a draft to no one yet).
    private var namedSender: Person? {
        thread.namesSomeone ? thread.sender : nil
    }

    /// The sender's name, their address when the message has no name, else "Draft" or
    /// "Unknown sender".
    private var senderName: String {
        thread.shownSender(drafts: inDrafts)
    }
}
