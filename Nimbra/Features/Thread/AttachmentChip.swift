import SwiftUI

/// A file under a message: its tile, name, kind and size.
struct AttachmentChip: View {
    let attachment: Attachment

    var body: some View {
        HStack(spacing: 12) {
            Icon(.file, size: 18)
                .foregroundStyle(Color.onAccent)
                .frame(width: 36, height: 36)
                .background(Color.accentRose, in: .rect(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: attachment.name)
                    .nimbraText(.subheadMedium)
                    .foregroundStyle(Color.textPrimary)
                Text(verbatim: "\(attachment.kind) · \(attachment.size.formatted(.byteCount(style: .file)))")
                    .nimbraText(.caption)
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.surfaceHover, in: .rect(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.borderSubtle))
        .accessibilityElement(children: .combine)
    }
}
