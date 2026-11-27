import NimbraCore
import SwiftUI

/// 08 · Settings · Signature: its name, whether it is the account's default, and its
/// content as formatted text, as HTML, or previewed. Kept with the check; Back leaves it
/// as it was. A new signature (`signatureID` nil) is added when it is kept.
struct SignatureEditorView: View {
    let accountID: Account.ID
    let signatureID: String?

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Environment(\.fontResolutionContext) private var fontContext

    @State private var isLoaded = false
    @State private var name = ""
    @State private var isDefault = false
    @State private var mode = SignatureEditorMode.text
    @State private var text = AttributedString()
    @State private var selection = AttributedTextSelection()
    /// The HTML: what is edited in HTML, and the content when the text editor cannot keep
    /// all of it.
    @State private var source = ""
    /// The text editor keeps all of `source`.
    @State private var isComplete = true
    @State private var isSaving = false
    @State private var asksForLink = false
    @State private var typedLink = ""
    @State private var confirmsDelete = false

    /// The font the signature's text is in, made bold or italic for those runs.
    private let font = NimbraTextStyle.reading.font
    private static let nameLimit = 60

    var body: some View {
        SettingsScreen(title: Text("Signature")) {
            details
            SegmentedControl(options: SignatureEditorMode.allCases, selection: $mode) { Text($0.label) }
                .padding(.top, 4)
            editor
                .padding(.top, 4)
            GroupFootnote("Links, tables and images from the web are kept. Scripts and forms are taken out when it is saved.")
            if let signature {
                GroupCard {
                    Button { confirmsDelete = true } label: {
                        ListRow(Text("Delete signature"), icon: .trash, titleColor: .accentRose, iconColor: .accentRose, divider: false)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)
                .alert(Text("Delete “\(signature.name)”?"), isPresented: $confirmsDelete) {
                    Button("Cancel", role: .cancel) {}
                    Button("Delete", role: .destructive) { delete(signature) }
                } message: {
                    Text("New messages can no longer use it. Messages already sent and drafts keep it as they are.")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if mode == .text, isComplete {
                SignatureFormattingBar(isOn: isOn, toggle: toggle) { asksForLink = true }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: save) {
                    Label { Text("Save") } icon: { Icon(.done).foregroundStyle(Color.textPrimary) }
                }
                .disabled(isSaving)
            }
        }
        .alert("Add a link", isPresented: $asksForLink) {
            TextField("Paste or type a link", text: $typedLink)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
            Button("Cancel", role: .cancel) { typedLink = "" }
            Button("Add") { addLink() }
        }
        .onChange(of: mode) { old, new in switchMode(from: old, to: new) }
        .onChange(of: name) { _, new in
            let line = String(new.prefix { !$0.isNewline }.prefix(Self.nameLimit))
            if line != new { name = line }
        }
        .task { await load() }
    }

    private var signature: SignatureInfo? {
        app.signatures[accountID]?.first { $0.id == signatureID }
    }

    private var accountName: String {
        app.accounts.first { $0.id == accountID }?.name ?? ""
    }

    // MARK: Parts

    private var details: some View {
        GroupCard {
            FieldRow("Name", divider: false) {
                TextField(text: $name, prompt: .fieldPrompt("Untitled")) { Text("Name") }
                    .submitLabel(.done)
            }
            SettingsToggleRow(title: Text("Default for \(accountName)"), isOn: $isDefault)
        }
    }

    @ViewBuilder
    private var editor: some View {
        Group {
            switch mode {
            case .text:
                if isComplete {
                    TextEditor(text: $text, selection: $selection)
                        .nimbraText(.reading)
                        .foregroundStyle(Color.textPrimary)
                        .scrollContentBackground(.hidden)
                        .scrollDisabled(true)
                        .accessibilityLabel(Text("Signature"))
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("This signature has HTML the text editor can’t keep. Edit it in HTML.")
                            .nimbraText(.subhead)
                            .foregroundStyle(Color.textSecondary)
                        Button("Edit in HTML") { mode = .html }
                            .nimbraText(.subheadMedium)
                            .foregroundStyle(Color.accentColor)
                    }
                    .padding(.vertical, 8)
                }
            case .html:
                TextEditor(text: $source)
                    .nimbraText(.mono)
                    .foregroundStyle(Color.textPrimary)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .scrollContentBackground(.hidden)
                    .scrollDisabled(true)
                    .accessibilityLabel(Text("Signature’s HTML"))
            case .preview:
                let preview = SignatureHTML.text(from: currentHTML, font: font, preview: true).text
                Group {
                    if preview.characters.isEmpty {
                        Text("This signature is empty.").foregroundStyle(Color.textTertiary)
                    } else {
                        Text(preview).foregroundStyle(Color.textPrimary)
                    }
                }
                .nimbraText(.reading)
                .tint(Color.accentColor)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 176, alignment: .topLeading)
        .padding(.horizontal, mode == .preview || !isComplete ? 16 : 11)
        .padding(.top, 6)
        .padding(.bottom, 10)
        .background(Color.surfaceHover, in: .rect(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.borderSubtle))
        .tint(Color.accentColor)
    }

    // MARK: Content

    /// The HTML as it stands: from the text editor when it holds it all, else as typed.
    private var currentHTML: String {
        mode == .text && isComplete ? SignatureHTML.html(from: text, context: fontContext) : source
    }

    private func load() async {
        guard !isLoaded else { return }
        isLoaded = true
        if app.signatures[accountID] == nil { await app.loadSignatures(accountID) }
        if let signature {
            name = signature.name
            isDefault = signature.isDefault
            source = signature.html
        } else {
            name = String(localized: "Signature")
            isDefault = app.signatures[accountID]?.isEmpty ?? true
        }
        readSource()
    }

    private func readSource() {
        let parsed = SignatureHTML.text(from: source, font: font)
        text = parsed.text
        isComplete = parsed.isComplete
        selection = AttributedTextSelection()
    }

    private func switchMode(from old: SignatureEditorMode, to new: SignatureEditorMode) {
        if old == .text, isComplete { source = SignatureHTML.html(from: text, context: fontContext) }
        if new == .text { readSource() }
    }

    // MARK: Formatting

    private func isOn(_ style: SignatureStyle) -> Bool {
        let attributes = selection.typingAttributes(in: text)
        switch style {
        case .bold: return (attributes.font ?? font).resolve(in: fontContext).isBold
        case .italic: return (attributes.font ?? font).resolve(in: fontContext).isItalic
        case .underline: return attributes.underlineStyle != nil && attributes.link == nil
        }
    }

    private func toggle(_ style: SignatureStyle) {
        let on = !isOn(style)
        text.transformAttributes(in: &selection) { container in
            let current = (container.font ?? font).resolve(in: fontContext)
            switch style {
            case .bold: container.font = SignatureHTML.styled(font, bold: on, italic: current.isItalic)
            case .italic: container.font = SignatureHTML.styled(font, bold: current.isBold, italic: on)
            case .underline: container.underlineStyle = on ? .single : nil
            }
        }
    }

    /// Links the selected words, or puts the link itself in at the caret.
    private func addLink() {
        defer { typedLink = "" }
        guard let url = SignatureHTML.link(from: typedLink) else { return }
        if case .ranges(let ranges) = selection.indices(in: text), !ranges.isEmpty {
            text.transformAttributes(in: &selection) { container in
                container.link = url
                container.foregroundColor = .accentColor
                container.underlineStyle = .single
            }
        } else {
            var link = AttributedString(typedLink.trimmingCharacters(in: .whitespacesAndNewlines))
            SignatureHTML.styleLink(&link, url)
            text.replaceSelection(&selection, with: link)
        }
    }

    // MARK: Keeping

    private func save() {
        let html = currentHTML
        let name = name.trimmingCharacters(in: .whitespaces)
        isSaving = true
        Task {
            defer { isSaving = false }
            if await app.saveSignature(signatureID, account: accountID, name: name, html: html, isDefault: isDefault) {
                dismiss()
            }
        }
    }

    private func delete(_ signature: SignatureInfo) {
        Task {
            if await app.deleteSignature(signature) { dismiss() }
        }
    }
}
