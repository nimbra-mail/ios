import SwiftUI

/// The kit's Pill: a label's name after a small dot (violet; an account's tone in All
/// inboxes, rose for a draft).
struct LabelPill: View {
    let name: String
    var dot = Color.accentColor

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(dot)
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
