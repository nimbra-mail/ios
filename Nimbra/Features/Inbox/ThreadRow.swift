import SwiftUI

/// The kit's Thread Row: avatar, sender, count and label, time, subject, and
/// two lines of the latest message.
struct ThreadRow: View {
    let thread: MailThread

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let sender = thread.sender {
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
                    if let label = thread.labels.first {
                        LabelPill(name: label)
                    }
                    Spacer(minLength: 4)
                    Text(verbatim: MailDate.short(thread.snoozedUntil ?? thread.date))
                        .nimbraText(.footnote)
                        .foregroundStyle(Color.textTertiary)
                }
                Text(verbatim: thread.subject)
                    .nimbraText(.subheadMedium)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                Text(verbatim: thread.snippet)
                    .nimbraText(.subhead)
                    .foregroundStyle(Color.textTertiary)
                    .lineLimit(2)
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

    /// The sender's name, or their address when the message has no name.
    private var senderName: String {
        guard let sender = thread.sender else { return "" }
        return sender.name.isEmpty ? sender.email : sender.name
    }
}
