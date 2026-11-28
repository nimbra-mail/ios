import NimbraCore
import SwiftUI

/// A message in full: who it is from and to (tapping "to …" shows the details card), its
/// body (the original HTML in the mail view, else the reader, at the mail text size), a
/// notice while its remote images are hidden, and its files. Tapping the header folds it.
struct MessageView: View {
    let message: Message
    let thread: MailThread.ID
    /// A tapped link: the thread shows the address before leaving the app.
    let open: (URL) -> Void
    /// Shows a downloaded attachment in Quick Look.
    let preview: (URL) -> Void
    /// Folds the message into the card of folded ones.
    let fold: () -> Void
    @Environment(AppModel.self) private var app
    @State private var showsDetails = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if showsDetails {
                MessageDetails(message: message)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            if hidesImages {
                RemoteImagesNotice { app.imagesAllowed.insert(message.id) }
            }
            content
                .environment(\.mailTextScale, app.preferences.textSize.scale)
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
                Button {
                    withAnimation(.smooth(duration: 0.25)) { showsDetails.toggle() }
                } label: {
                    Text(verbatim: recipients)
                        .nimbraText(.footnote)
                        .foregroundStyle(Color.textTertiary)
                        .lineLimit(1)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityHint(showsDetails ? Text("Hides the details") : Text("Shows the details"))
            }
            Spacer(minLength: 8)
            HStack(spacing: 8) {
                Text(verbatim: MailDate.short(message.date))
                    .nimbraText(.footnote)
                    .foregroundStyle(Color.textTertiary)
                FoldMark(isOpen: true)
            }
        }
        .contentShape(.rect)
        .onTapGesture(perform: fold)
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: Text("Fold"), fold)
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
        let names = message.recipients.map(\.firstName)
        let shown = names.prefix(2).joined(separator: ", ")
        return names.count > 2
            ? String(localized: "to \(shown) and \(names.count - 2) more")
            : String(localized: "to \(shown)")
    }
}
