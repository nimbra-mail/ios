import SwiftUI

/// Folded messages, one line each, in a card. Tapping one opens it in full.
struct FoldedMessages: View {
    let messages: [Message]
    let thread: MailThread.ID
    let expand: (Message) -> Void
    @Environment(AppModel.self) private var app

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                if index > 0 { Divider().overlay(Color.borderSubtle) }
                Button { expand(message) } label: { row(message) }
                    .buttonStyle(.plain)
                    .accessibilityHint(Text("Shows the whole message"))
            }
        }
        .background(Color.surfaceHover, in: .rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.borderSubtle))
    }

    private func row(_ message: Message) -> some View {
        HStack(spacing: 10) {
            AvatarView(person: message.from, size: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: app.shownFrom(message, in: thread))
                    .nimbraText(.subheadMedium)
                    .foregroundStyle(Color.textPrimary)
                Text(verbatim: message.preview)
                    .nimbraText(.footnote)
                    .foregroundStyle(Color.textTertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(verbatim: MailDate.short(message.date))
                .nimbraText(.caption)
                .foregroundStyle(Color.textFaint)
            FoldMark(isOpen: false)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

/// The fold arrow after a message's time: down while folded, turned up while open.
struct FoldMark: View {
    let isOpen: Bool

    var body: some View {
        Icon(.down, size: 14)
            .foregroundStyle(Color.textFaint)
            .rotationEffect(.degrees(isOpen ? 180 : 0))
    }
}
