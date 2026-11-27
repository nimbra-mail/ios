import SwiftUI

/// Attach, the text styles, Link and Send later, in a Liquid Glass capsule over the
/// keyboard. A style that is on at the caret takes the accent on the selected fill.
struct FormattingBar: View {
    let editor: ComposeEditorModel
    let hasAttachments: Bool
    let isSchedulingLater: Bool
    let attachPhotos: () -> Void
    let attachFiles: () -> Void
    let link: () -> Void
    let sendLater: () -> Void

    var body: some View {
        HStack(spacing: 2) {
            Menu {
                Button(action: attachPhotos) {
                    Label { Text("Photos") } icon: { Icon(.image) }
                }
                Button(action: attachFiles) {
                    Label { Text("Files") } icon: { Icon(.file) }
                }
            } label: {
                face(.clip, isOn: hasAttachments)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Attach"))
            tool(.bold, "Bold", isOn: editor.isBold) { editor.exec("bold") }
            tool(.italic, "Italic", isOn: editor.isItalic) { editor.exec("italic") }
            tool(.underline, "Underline", isOn: editor.isUnderlined) { editor.exec("underline") }
            tool(.bullets, "Bulleted list", isOn: editor.isBulleted) { editor.exec("insertUnorderedList") }
            tool(.link, "Link", isOn: editor.link != nil, link)
            tool(.clock, "Send later", isOn: isSchedulingLater, sendLater)
        }
        .padding(4)
        .glassEffect(.regular.interactive(), in: .capsule)
        .padding(.bottom, 8)
    }

    private func tool(_ icon: NimbraIcon, _ label: LocalizedStringKey, isOn: Bool, _ run: @escaping () -> Void) -> some View {
        Button(action: run) {
            face(icon, isOn: isOn)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private func face(_ icon: NimbraIcon, isOn: Bool) -> some View {
        Icon(icon, size: 18)
            .foregroundStyle(isOn ? Color.accentColor : Color.textPrimary)
            .frame(width: 46, height: 44)
            .background(isOn ? Color.surfaceSelected : .clear, in: .capsule)
            .contentShape(.capsule)
    }
}
