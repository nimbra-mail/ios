import SwiftUI

/// A message in full: who it is from and to, its text and its files.
struct MessageView: View {
    let message: Message

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                AvatarView(person: message.from, size: 36)
                VStack(alignment: .leading, spacing: 1) {
                    Text(verbatim: message.from.name)
                        .nimbraText(.sender)
                        .foregroundStyle(Color.textPrimary)
                    Text(verbatim: recipients)
                        .nimbraText(.footnote)
                        .foregroundStyle(Color.textTertiary)
                }
                Spacer(minLength: 8)
                Text(verbatim: MailDate.short(message.date))
                    .nimbraText(.footnote)
                    .foregroundStyle(Color.textTertiary)
            }
            .accessibilityElement(children: .combine)
            Text(verbatim: message.body)
                .nimbraText(.reading)
                .foregroundStyle(Color.textSecondary)
                .textSelection(.enabled)
            ForEach(message.attachments, id: \.name) { file in
                AttachmentChip(attachment: file)
            }
        }
    }

    /// "to Luan, Jonah and 1 more".
    private var recipients: String {
        let names = message.to.map(\.firstName)
        let shown = names.prefix(2).joined(separator: ", ")
        return names.count > 2
            ? String(localized: "to \(shown) and \(names.count - 2) more")
            : String(localized: "to \(shown)")
    }
}
