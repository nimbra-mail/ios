import SwiftUI

/// The kit's Pill: a label's name after a small violet dot.
struct LabelPill: View {
    let name: String

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.accentColor)
                .frame(width: 6, height: 6)
            Text(verbatim: name)
                .nimbraText(.caption)
                .foregroundStyle(Color.textSecondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.surfaceHover, in: .capsule)
        .overlay(Capsule().strokeBorder(Color.borderSubtle))
    }
}
