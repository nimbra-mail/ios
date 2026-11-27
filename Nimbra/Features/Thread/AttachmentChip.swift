import SwiftUI
import UniformTypeIdentifiers

/// A file under a message: its tile, name, kind and size. Tapping it downloads it into a
/// protected file and opens it in Quick Look (which can share it); holding it offers
/// Quick Look and Share.
struct AttachmentChip: View {
    let attachment: Attachment
    let thread: MailThread.ID
    /// Shows the downloaded file in Quick Look.
    let preview: (URL) -> Void
    @Environment(AppModel.self) private var app
    @State private var isDownloading = false

    var body: some View {
        Button(action: open) { chip }
            .buttonStyle(.plain)
            .disabled(isDownloading)
            .contextMenu {
                Button(action: open) {
                    Label { Text("Quick Look") } icon: { Icon(.eye) }
                }
                ShareLink(item: download, preview: SharePreview(Text(verbatim: attachment.name)))
            }
            .accessibilityHint(Text("Opens the file"))
    }

    private var chip: some View {
        HStack(spacing: 12) {
            Group {
                if isDownloading {
                    ProgressView().tint(Color.onAccent)
                } else {
                    Icon(.file, size: 18)
                }
            }
            .foregroundStyle(Color.onAccent)
            .frame(width: 36, height: 36)
            .background(Color.accentRose, in: .rect(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: attachment.name)
                    .nimbraText(.subheadMedium)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(verbatim: "\(attachment.kind) · \(attachment.size.formatted(.byteCount(style: .file)))")
                    .nimbraText(.caption)
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.surfaceHover, in: .rect(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.borderSubtle))
        .contentShape(.rect(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }

    private func open() {
        guard !isDownloading else { return }
        isDownloading = true
        Task {
            defer { isDownloading = false }
            if let url = await app.attachmentFile(attachment, in: thread) { preview(url) }
        }
    }

    /// The file for the share sheet, downloaded when it is shared.
    private var download: AttachmentDownload {
        AttachmentDownload(name: attachment.name) { [app, attachment, thread] in
            guard let url = await app.attachmentFile(attachment, in: thread) else { throw CocoaError(.fileReadUnknown) }
            return url
        }
    }
}

/// An attachment as the share sheet takes it: its file, fetched only once shared.
nonisolated struct AttachmentDownload: Transferable {
    let name: String
    let fetch: @Sendable () async throws -> URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .data) { item in
            SentTransferredFile(try await item.fetch())
        }
        .suggestedFileName { $0.name }
    }
}
