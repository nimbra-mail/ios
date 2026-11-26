import SwiftUI

/// Attach, the text styles and Send later, in a Liquid Glass capsule. The
/// styles toggle; applying them to the text comes with the rich editor.
struct FormattingBar: View {
    @State private var styles: Set<NimbraIcon> = []

    private let tools: [(NimbraIcon, LocalizedStringKey)] = [
        (.bold, "Bold"), (.italic, "Italic"), (.underline, "Underline"), (.bullets, "Bulleted list"), (.link, "Link"),
    ]

    var body: some View {
        HStack(spacing: 2) {
            tool(.clip, "Attach", isOn: false) {}
            ForEach(tools, id: \.0) { icon, label in
                tool(icon, label, isOn: styles.contains(icon)) {
                    if styles.remove(icon) == nil { styles.insert(icon) }
                }
            }
            tool(.clock, "Send later", isOn: false) {}
        }
        .padding(4)
        .glassEffect(.regular.interactive(), in: .capsule)
        .padding(.bottom, 8)
    }

    private func tool(_ icon: NimbraIcon, _ label: LocalizedStringKey, isOn: Bool, _ run: @escaping () -> Void) -> some View {
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
