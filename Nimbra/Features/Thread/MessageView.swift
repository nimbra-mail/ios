import NimbraCore
import SwiftUI

/// A message in full: who it is from and to, its body (the original HTML in the mail view,
/// else the reader), a notice while its remote images are hidden, and its files.
struct MessageView: View {
    let message: Message
    let thread: MailThread.ID
    /// A tapped link: the thread shows the address before leaving the app.
    let open: (URL) -> Void
    /// Shows a downloaded attachment in Quick Look.
    let preview: (URL) -> Void
    @Environment(AppModel.self) private var app

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if hidesImages {
                RemoteImagesNotice { app.imagesAllowed.insert(message.id) }
            }
            content
            ForEach(message.attachments, id: \.self) { file in
                AttachmentChip(attachment: file, thread: thread, preview: preview)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            AvatarView(person: message.from, size: 36)
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: app.shownFrom(message, in: thread))
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
    }

    @ViewBuilder
    private var content: some View {
        if app.showsOriginal(message), let html = message.html {
            MailHTMLView(html: html, images: app.loadsImages(message), open: open)
                // Edge to edge: the mail's own background fills the width, and its page
                // keeps the margin (`MailDocument.defaults`).
                .padding(.horizontal, -20)
        } else if message.hasNoContent {
            Text("No content")
                .nimbraText(.reading)
                .foregroundStyle(Color.textSecondary)
        } else if !message.blocks.isEmpty {
            ReaderBlocks(blocks: message.blocks, images: app.loadsImages(message))
        } else {
            Text(verbatim: message.body)
                .nimbraText(.reading)
                .foregroundStyle(Color.textSecondary)
                .textSelection(.enabled)
        }
    }

    /// Remote images are in the message and not loading: the notice offers them.
    private var hidesImages: Bool {
        guard !app.loadsImages(message) else { return false }
        if app.showsOriginal(message), let html = message.html {
            return MailDocument.hasRemoteImages(html)
        }
        return message.blocks.contains { if case .image = $0.kind { true } else { false } }
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
