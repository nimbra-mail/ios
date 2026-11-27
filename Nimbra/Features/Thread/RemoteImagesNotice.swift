import SwiftUI

/// Above a message whose remote images are hidden: why, and Load images, as on the Mac.
struct RemoteImagesNotice: View {
    let load: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Icon(.eye, size: 18)
                .foregroundStyle(Color.textTertiary)
            Text("Remote images are hidden to protect your privacy.")
                .nimbraText(.footnote)
                .foregroundStyle(Color.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: load) {
                Text("Load images")
                    .nimbraText(.subheadMedium)
                    .foregroundStyle(Color.accentColor)
                    .frame(minHeight: 44)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 12)
        .padding(.trailing, 14)
        .padding(.vertical, 4)
        .background(Color.surfaceHover, in: .rect(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.borderSubtle))
    }
}
