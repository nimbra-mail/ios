import SwiftUI

/// A mailbox in a Mailboxes card (the kit's List Row): its icon, its name and its count;
/// a hairline above every row but the first.
struct MailboxRow: View {
    let icon: NimbraIcon
    var iconColor = Color.textPrimary
    let title: Text
    var titleColor = Color.textPrimary
    var count = 0
    var divider = true

    var body: some View {
        HStack(spacing: 12) {
            Icon(icon).foregroundStyle(iconColor)
            title
                .nimbraText(.body)
                .foregroundStyle(titleColor)
                .lineLimit(1)
            Spacer(minLength: 8)
            if count > 0 {
                Text(count, format: .number)
                    .nimbraText(.subhead)
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .frame(minHeight: 50)
        .contentShape(.rect)
        .overlay(alignment: .top) {
            if divider { Rectangle().fill(Color.borderSubtle).frame(height: 1) }
        }
        .accessibilityElement(children: .combine)
    }
}
