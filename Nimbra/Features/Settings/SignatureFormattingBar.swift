import SwiftUI

/// The text styles for a signature in a Liquid Glass capsule: bold, italic, underline and
/// a link, each lit while the text at the caret has it.
struct SignatureFormattingBar: View {
    let isOn: (SignatureStyle) -> Bool
    let toggle: (SignatureStyle) -> Void
    let addLink: () -> Void

    var body: some View {
        HStack(spacing: 2) {
            ForEach(SignatureStyle.allCases) { style in
                tool(style.icon, style.label, isOn: isOn(style)) { toggle(style) }
            }
            tool(.link, "Link", isOn: false, addLink)
        }
        .padding(4)
        .glassEffect(.regular.interactive(), in: .capsule)
        .padding(.bottom, 8)
    }

    private func tool(_ icon: NimbraIcon, _ label: LocalizedStringResource, isOn: Bool, _ run: @escaping () -> Void) -> some View {
        Button(action: run) {
            Icon(icon, size: 18)
                .foregroundStyle(isOn ? Color.accentColor : Color.textPrimary)
                .frame(width: 46, height: 44)
                .background(isOn ? Color.surfaceSelected : .clear, in: .capsule)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
