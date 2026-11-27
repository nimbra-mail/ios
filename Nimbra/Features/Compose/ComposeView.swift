import NimbraCore
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// 04 · Compose: From, To (Cc and Bcc on demand), Subject, the files, and the message
/// with its signature, with the formatting bar floating at the bottom. The 13 frames add
/// the address suggestions, the From menu, the files and Send later.
struct ComposeView: View {
    let composer: Composer
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var editor = ComposeEditorModel()
    @FocusState private var focus: Focus?
    @State private var suggestions: [Person] = []
    @State private var isPickingFrom = false
    @State private var isClosing = false
    @State private var isPickingSignature = false
    @State private var signatures: [SignatureInfo] = []
    @State private var isLinking = false
    @State private var linkText = ""
    @State private var isSchedulingLater = false
    @State private var isPickingPhotos = false
    @State private var photos: [PhotosPickerItem] = []
    @State private var isImportingFiles = false
    @State private var fromFrame = CGRect.zero

    enum Focus: Hashable {
        case recipients(Composer.Field), subject
    }

    var body: some View {
        @Bindable var composer = composer
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                header
                FromField(account: fromAccount, isPicking: isPickingFrom) {
                    focus = nil
                    withAnimation(.smooth(duration: 0.2)) { isPickingFrom.toggle() }
                }
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.space)) } action: { fromFrame = $0 }
                recipients(.to)
                if composer.showsCcBcc {
                    recipients(.cc)
                    recipients(.bcc)
                }
                ComposeField(label: "Subject") {
                    TextField(text: $composer.subject, prompt: Text(verbatim: "")) { Text("Subject") }
                        .nimbraText(.subheadMedium)
                        .foregroundStyle(Color.textPrimary)
                        .focused($focus, equals: .subject)
                        .submitLabel(.next)
                        .onSubmit { focus = nil; editor.focus() }
                        .onChange(of: composer.subject) { app.composerChanged(composer) }
                        .accessibilityLabel(Text("Subject"))
                }
                if !composer.files.isEmpty || !composer.kept.isEmpty {
                    AttachmentStrip(
                        composer: composer,
                        removeFile: { app.removeFile($0, from: composer) },
                        removeKept: { app.removeKept($0, from: composer) }
                    )
                }
                if let notice = composer.notice {
                    NoticeRow(icon: .alert, iconColor: .accentRose, text: Text(verbatim: notice), textColor: .textSecondary)
                        .padding(.horizontal, 4)
                        .overlay(alignment: .top) { Divider().overlay(Color.borderSubtle) }
                }
                ComposeEditor(editor: editor)
                    .overlay(alignment: .top) { Divider().overlay(Color.borderSubtle) }
                    .accessibilityLabel(Text("Message"))
            }
            if isPickingFrom {
                Color.clear
                    .contentShape(.rect)
                    .onTapGesture { withAnimation(.smooth(duration: 0.2)) { isPickingFrom = false } }
                    .accessibilityHidden(true)
                FromMenu(accounts: app.accounts, selected: composer.from) { account in
                    withAnimation(.smooth(duration: 0.2)) { isPickingFrom = false }
                    Task { await app.setFrom(account, for: composer) }
                }
                .frame(maxWidth: 320)
                .padding(.leading, max(fromFrame.minX + 89, 16))
                .padding(.trailing, 12)
                .offset(y: fromFrame.maxY + 2)
                .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .topLeading)))
            }
        }
        .coordinateSpace(.named(Self.space))
        .background(Color.surfaceRaised)
        .safeAreaInset(edge: .bottom) {
            FormattingBar(
                editor: editor,
                hasAttachments: !composer.files.isEmpty || !composer.kept.isEmpty,
                isSchedulingLater: isSchedulingLater,
                attachPhotos: { isPickingPhotos = true },
                attachFiles: { isImportingFiles = true },
                link: startLink,
                sendLater: { focus = nil; editor.blur(); isSchedulingLater = true }
            )
        }
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.surfaceRaised)
        .task(id: query) { await suggest() }
        .onAppear(perform: setUp)
        .onChange(of: composer.signature) { editor.showSignature(composer.signature?.html) }
        .confirmationDialog("Save this draft?", isPresented: $isClosing, titleVisibility: .visible) {
            Button("Save draft") { app.close(composer) }
            Button("Delete draft", role: .destructive) { app.discard(composer) }
            Button("Keep writing", role: .cancel) {}
        }
        .confirmationDialog("Signature", isPresented: $isPickingSignature) {
            ForEach(signatures, id: \.id) { signature in
                Button(signature.name.isEmpty ? String(localized: "Signature") : signature.name) {
                    app.setSignature(signature, for: composer)
                }
            }
            Button("No signature") { app.setSignature(nil, for: composer) }
        }
        .alert("Link", isPresented: $isLinking) {
            TextField("https://", text: $linkText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
            Button("Cancel", role: .cancel) { editor.focus() }
            if editor.link != nil {
                Button("Remove link", role: .destructive) { editor.setLink("") }
            }
            Button("Add") { editor.setLink(linkText) }
        } message: {
            Text("Paste or type a link. An address becomes a mail link.")
        }
        .sheet(isPresented: $isSchedulingLater) {
            SendLaterSheet(subject: composer.subject, times: app.sendLaterTimes) { date in
                Task { await app.scheduleSend(composer, at: date) }
            }
        }
        .photosPicker(isPresented: $isPickingPhotos, selection: $photos, maxSelectionCount: 10, matching: .images)
        .onChange(of: photos) {
            let picked = photos
            photos = []
            guard !picked.isEmpty else { return }
            Task { app.attach(await Attachments.photos(picked), to: composer) }
        }
        .fileImporter(isPresented: $isImportingFiles, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
            guard case .success(let urls) = result else { return }
            Task { app.attach(await Attachments.files(urls), to: composer) }
        }
    }

    private nonisolated static let space = "compose"

    // MARK: Parts

    private var header: some View {
        HStack(spacing: 8) {
            GlassIconButton(icon: .x, label: "Close") {
                if composer.hasContent { isClosing = true } else { app.close(composer) }
            }
            Text(title)
                .nimbraText(.headline)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .accessibilityAddTraits(.isHeader)
            Button {
                focus = nil
                Task { await app.send(composer) }
            } label: {
                Group {
                    if composer.isSending {
                        ProgressView().tint(Color.onAccent)
                    } else {
                        Icon(.send, size: 20).foregroundStyle(Color.onAccent)
                    }
                }
                .frame(width: 44, height: 44)
                .background(.brandButton, in: .circle)
            }
            .buttonStyle(.plain)
            .glassEffect(.clear.interactive(), in: .circle)
            .disabled(composer.isSending)
            .accessibilityLabel(Text("Send"))
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private func recipients(_ field: Composer.Field) -> some View {
        RecipientField(
            composer: composer,
            field: field,
            focus: $focus,
            showCcBcc: field == .to && !composer.showsCcBcc
                ? { withAnimation(.smooth(duration: 0.2)) { composer.showsCcBcc = true }; focus = .recipients(.cc) }
                : nil,
            changed: { app.composerChanged(composer) },
            submit: {
                composer.chipify(field, all: true)
                focus = switch field {
                case .to: composer.showsCcBcc ? .recipients(.cc) : .subject
                case .cc: .recipients(.bcc)
                case .bcc: .subject
                }
            }
        )
        if case .recipients(field) = focus, !suggestions.isEmpty {
            SuggestionList(people: suggestions, typed: composer[keyPath: Composer.typing(field)]) { person in
                composer.add(person.email, to: field)
                suggestions = []
                app.composerChanged(composer)
            }
        }
    }

    private var title: LocalizedStringKey {
        switch composer.kind {
        case .reply, .replyAll: "Reply"
        case .forward: "Forward"
        case .draft: "Draft"
        case .new: "New message"
        }
    }

    private var fromAccount: Account? {
        app.accounts.first { $0.id == composer.from }
    }

    // MARK: Behaviour

    /// What is typed in the field with the focus, for the suggestions.
    private var query: String {
        guard case .recipients(let field) = focus else { return "" }
        return composer[keyPath: Composer.typing(field)]
    }

    private func suggest() async {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            suggestions = []
            return
        }
        // While typing goes on, wait for a pause.
        try? await Task.sleep(for: .milliseconds(120))
        guard !Task.isCancelled else { return }
        suggestions = await app.suggestions(for: query, in: composer)
    }

    private func setUp() {
        if composer.from.isEmpty, let from = app.defaultFrom {
            // From a sheet of its own (`init(draft:)`): the app's composer takes it over.
            composer.from = from
            dismiss()
            Task {
                try? await Task.sleep(for: .milliseconds(450))
                app.presentedComposer = composer
            }
            return
        }
        editor.changed = { html, text in
            composer.written = html
            composer.text = text
            app.composerChanged(composer)
        }
        editor.signatureText = { composer.signatureText = $0 }
        editor.signatureMenu = {
            Task {
                signatures = await app.signatures(for: composer.from)
                isPickingSignature = true
            }
        }
        editor.focused = {
            focus = nil
            if isPickingFrom { isPickingFrom = false }
        }
        editor.ready = {
            editor.load(html: composer.written, quoted: composer.quoted, focus: false)
            editor.showSignature(composer.signature?.html)
        }
        if composer.to.isEmpty && composer.kind != .draft {
            focus = .recipients(.to)
        }
        #if DEBUG
        switch AppModel.ComposeDemo.launch {
        case .from: isPickingFrom = true
        case .suggestions: focus = .recipients(.to)
        case .sendLater: isSchedulingLater = true
        default: break
        }
        #endif
    }

    private func startLink() {
        linkText = editor.link.map { $0.replacingOccurrences(of: "mailto:", with: "") } ?? ""
        isLinking = true
    }
}

#Preview {
    let app = AppModel.sample()
    let composer = Composer(kind: .reply, from: SampleData.work.id)
    composer.to = ["mira@northwind.studio"]
    composer.subject = "Re: Q4 launch plan"
    return Color.clear.sheet(isPresented: .constant(true)) {
        ComposeView(composer: composer)
    }
    .environment(app)
}
