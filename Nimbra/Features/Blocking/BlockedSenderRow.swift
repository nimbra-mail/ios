import SwiftUI

/// A blocked sender (the kit's Account Row): their avatar and address, and Unblock. The
/// engine keeps the address only, so the address is the row's name.
struct BlockedSenderRow: View {
    let address: String
    let divider: Bool
    let unblock: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(person: Person(name: "", email: address), size: 28)
            Text(verbatim: address)
                .nimbraText(.body)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: unblock) {
                Text("Unblock")
                    .nimbraText(.subhead)
                    .foregroundStyle(Color.accentColor)
                    .frame(minHeight: 44)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Unblock \(address)"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(minHeight: 63)
        .overlay(alignment: .top) {
            if divider { Rectangle().fill(Color.borderSubtle).frame(height: 1) }
        }
    }
}
