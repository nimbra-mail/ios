import NimbraCore
import SwiftUI

/// The files going with the message (13 · Compose · Attachments): tiles in a row that
/// scrolls, and how much of the 25 MB they take.
struct AttachmentStrip: View {
    let composer: Composer
    let removeFile: (Composer.File.ID) -> Void
    let removeKept: (AttachmentInfo) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(composer.kept, id: \.self) { kept in
                        AttachmentTile(name: kept.name, mime: kept.mime, size: Int64(kept.size)) { removeKept(kept) }
                    }
                    ForEach(composer.files) { file in
                        AttachmentTile(name: file.name, mime: file.mime, size: Int64(file.bytes.count)) { removeFile(file.id) }
                    }
                }
                .padding(.trailing, 20)
            }
            .scrollIndicators(.hidden)
            Text(summary)
                .nimbraText(.footnote)
                .foregroundStyle(Color.textTertiary)
        }
        .padding(.leading, 20)
        .padding(.vertical, 12)
        .overlay(alignment: .top) { Divider().overlay(Color.borderSubtle) }
    }

    /// "2 files · 5.1 MB of 25 MB".
    private var summary: String {
        let count = composer.kept.count + composer.files.count
        let used = composer.attachmentBytes.formatted(.byteCount(style: .file))
        // The limit is 25 MiB; it is called 25 MB, as on the Mac.
        return count == 1
            ? String(localized: "1 file · \(used) of 25 MB")
            : String(localized: "\(count) files · \(used) of 25 MB")
    }
}

/// One file: its tile (a picture's in sky, any other in rose), name, kind and size, and ✕.
struct AttachmentTile: View {
    let name: String
    let mime: String
    let size: Int64
    let remove: () -> Void

    private var isImage: Bool { mime.hasPrefix("image/") }

    var body: some View {
        HStack(spacing: 12) {
            Icon(isImage ? .image : .file, size: 18)
                .foregroundStyle(Color.onAccent)
                .frame(width: 36, height: 36)
                .background(isImage ? Color.accentSky : Color.accentRose, in: .rect(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: name)
                    .nimbraText(.subheadMedium)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                Text(verbatim: "\(kind) · \(size.formatted(.byteCount(style: .file)))")
                    .nimbraText(.caption)
                    .foregroundStyle(Color.textTertiary)
            }
            .frame(maxWidth: 180, alignment: .leading)
            Button(action: remove) {
                Icon(.x, size: 14)
                    .foregroundStyle(Color.textTertiary)
                    .frame(width: 28, height: 28)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, -7)
            .accessibilityLabel(Text("Remove \(name)"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.surfaceHover, in: .rect(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.borderSubtle))
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: Text("Remove")) { remove() }
    }

    /// "PDF": the extension, else what the type says.
    private var kind: String {
        let ext = (name as NSString).pathExtension
        return (ext.isEmpty ? String(mime.split(separator: "/").last ?? "") : ext).uppercased()
    }
}
