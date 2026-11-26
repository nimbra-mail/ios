import SwiftUI

/// 04 · Compose: From, To, Subject, the message and its signature, with the
/// formatting bar floating at the bottom.
struct ComposeView: View {
    @State var draft: ComposeDraft
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var recipient = ""
    @FocusState private var focus: Field?

    private enum Field { case to, subject, body }

    var body: some View {
        @Bindable var app = app
        VStack(spacing: 0) {
            header
            ComposeField(label: "From") {
                Picker(selection: $app.shownAccountID) {
                    ForEach(app.accounts) { Text(verbatim: $0.email).tag($0.id) }
                } label: {
                    Text("From")
                }
                .pickerStyle(.menu)
                .tint(Color.textPrimary)
                .labelsHidden()
            }
            ComposeField(label: "To") {
                recipients
            }
            ComposeField(label: "Subject") {
                TextField("Subject", text: $draft.subject)
                    .nimbraText(.subheadMedium)
                    .foregroundStyle(Color.textPrimary)
                    .focused($focus, equals: .subject)
                    .submitLabel(.next)
                    .onSubmit { focus = .body }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    TextField("Message", text: $draft.body, axis: .vertical)
                        .nimbraText(.reading)
                        .foregroundStyle(Color.textPrimary)
                        .focused($focus, equals: .body)
                    SignatureBlock()
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
            }
            .overlay(alignment: .top) { Divider().overlay(Color.borderSubtle) }
        }
        .background(Color.surfaceRaised)
        .safeAreaInset(edge: .bottom) { FormattingBar() }
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.surfaceRaised)
        .onAppear { focus = draft.to.isEmpty ? .to : .body }
    }

    private var header: some View {
        HStack {
            GlassIconButton(icon: .x, label: "Close") { dismiss() }
            Spacer()
            Text(title)
                .nimbraText(.headline)
                .foregroundStyle(Color.textPrimary)
            Spacer()
            Button {
                dismiss()
            } label: {
                Icon(.send, size: 20)
                    .foregroundStyle(Color.onAccent)
                    .frame(width: 44, height: 44)
                    .background(.brand, in: .circle)
            }
            .buttonStyle(.plain)
            .glassEffect(.clear.interactive(), in: .circle)
            .disabled(draft.to.isEmpty && recipient.isEmpty)
            .accessibilityLabel(Text("Send"))
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }

    private var title: LocalizedStringKey {
        if draft.subject.hasPrefix("Re: ") { return "Reply" }
        if draft.subject.hasPrefix("Fwd: ") { return "Forward" }
        return "New message"
    }

    private var recipients: some View {
        HStack(spacing: 6) {
            ForEach(draft.to, id: \.self) { address in
                RecipientChip(address: address) { draft.to.removeAll { $0 == address } }
            }
            TextField(draft.to.isEmpty ? "name@example.com" : "", text: $recipient)
                .nimbraText(.subhead)
                .foregroundStyle(Color.textPrimary)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .focused($focus, equals: .to)
                .submitLabel(.next)
                .onSubmit {
                    let address = recipient.trimmingCharacters(in: .whitespaces)
                    if !address.isEmpty { draft.to.append(address) }
                    recipient = ""
                    focus = .subject
                }
        }
    }
}

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
        ComposeView(draft: .init(to: ["mira@northwind.studio"], subject: "Re: Q4 launch plan"))
    }
    .environment(AppModel.sample())
}
