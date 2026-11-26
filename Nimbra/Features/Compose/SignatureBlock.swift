import SwiftUI

/// The signature under the message, set apart by the handle (a short line
/// and a chevron) that will open the signature picker.
struct SignatureBlock: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Rectangle()
                    .fill(Color.textFaint)
                    .frame(width: 16, height: 1.5)
                Icon(.down, size: 12)
                    .foregroundStyle(Color.textFaint)
            }
            .accessibilityHidden(true)
            Text(verbatim: "Luan Gjokaj\nUX Engineer & Designer\nnimbra.me")
                .nimbraText(.subhead)
                .foregroundStyle(Color.textTertiary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Signature"))
    }
}
