import SwiftUI

/// To, Cc or Bcc: the addresses as chips, then what is being typed. A comma or a
/// semicolon finishes an address, as do Return and leaving the field.
struct RecipientField: View {
    @Bindable var composer: Composer
    let field: Composer.Field
    var focus: FocusState<ComposeView.Focus?>.Binding
    /// Shows Cc and Bcc (To only, while they are hidden).
    var showCcBcc: (() -> Void)?
    let changed: () -> Void
    let submit: () -> Void

    var body: some View {
        ComposeField(label: label, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                FlowLayout(spacing: 6, lineSpacing: 6) {
                    ForEach(composer.chips(field), id: \.self) { address in
                        RecipientChip(address: address) {
                            composer.setChips(composer.chips(field).filter { $0 != address }, field)
                            changed()
                        }
                    }
                    TextField(
                        text: $composer[dynamicMember: Composer.typing(field)],
                        prompt: composer.chips(field).isEmpty && field == .to
                            ? Text(verbatim: "name@example.com").foregroundStyle(Color.textFaint)
                            : nil
                    ) {
                        Text(label)
                    }
                        .nimbraText(.subhead)
                        .foregroundStyle(Color.textPrimary)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.emailAddress)
                        .submitLabel(.next)
                        .focused(focus, equals: .recipients(field))
                        // Room to type beside the chips; less while another field is being typed in.
                        .frame(minWidth: focus.wrappedValue == .recipients(field) || composer.chips(field).isEmpty ? 24 : 8)
                        .padding(.vertical, 4)
                        .onSubmit(submit)
                        .accessibilityLabel(Text(label))
                }
                if let showCcBcc {
                    Button(action: showCcBcc) {
                        Text("Cc Bcc")
                            .nimbraText(.subhead)
                            .foregroundStyle(Color.textTertiary)
                            .frame(minHeight: 28)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Show Cc and Bcc"))
                }
            }
        }
        .contentShape(.rect)
        .onTapGesture { focus.wrappedValue = .recipients(field) }
        .onChange(of: composer[keyPath: Composer.typing(field)]) {
            composer.chipify(field, all: false)
            changed()
        }
        .onChange(of: focus.wrappedValue) { old, new in
            if old == .recipients(field), new != old {
                composer.chipify(field, all: true)
            }
        }
    }

    private var label: LocalizedStringKey {
        switch field {
        case .to: "To"
        case .cc: "Cc"
        case .bcc: "Bcc"
        }
    }
}
