import SwiftUI

/// The kit's Segmented: a three-way choice (Theme, the signature's Text, HTML and
/// Preview). The selected segment is the selected Chip's look: surface/selected with an
/// accent edge. 44 pt tall.
struct SegmentedControl<Value: Hashable & Identifiable>: View {
    let options: [Value]
    @Binding var selection: Value
    let label: (Value) -> Text

    @ScaledMetric(relativeTo: .subheadline) private var height: CGFloat = 38

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options) { option in
                let isSelected = option == selection
                Button {
                    selection = option
                } label: {
                    label(option)
                        .nimbraText(.subheadMedium)
                        .foregroundStyle(isSelected ? Color.accentColor : Color.textSecondary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, minHeight: height)
                        .background {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 11)
                                    .fill(Color.surfaceSelected)
                                    .strokeBorder(Color.accentColor)
                            }
                        }
                        .contentShape(.rect(cornerRadius: 11))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(3)
        .background(Color.surfaceHover, in: .rect(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.borderSubtle))
        .animation(.smooth(duration: 0.2), value: selection)
    }
}
