import SwiftUI

/// New label, Rename and Delete label, as the Mac asks them (`labels.rs`): a name in an
/// alert, and a confirmation before a label is deleted.
struct LabelEditing: ViewModifier {
    @Binding var edit: LabelEdit?
    @Environment(AppModel.self) private var app
    @State private var name = ""

    func body(content: Content) -> some View {
        content
            .alert(nameTitle, isPresented: isNaming) {
                TextField("Label name", text: $name)
                    .textInputAutocapitalization(.words)
                Button("Cancel", role: .cancel) { edit = nil }
                Button(isRenaming ? "Rename" : "Create") { save() }
            } message: {
                nameHint
            }
            .confirmationDialog(deleteTitle, isPresented: isDeleting, titleVisibility: .visible) {
                Button("Delete label", role: .destructive) { delete() }
                Button("Cancel", role: .cancel) { edit = nil }
            } message: {
                deleteMessage
            }
            .onChange(of: edit) { _, edit in
                if case .rename(let label, _) = edit { name = label.name } else { name = "" }
            }
    }

    // MARK: Naming

    private var isNaming: Binding<Bool> {
        Binding {
            switch edit {
            case .new, .rename: true
            default: false
            }
        } set: { if !$0, !isDeleting.wrappedValue { edit = nil } }
    }

    private var isRenaming: Bool {
        if case .rename = edit { true } else { false }
    }

    private var nameTitle: Text {
        isRenaming ? Text("Rename label") : Text("New label")
    }

    private var hasOwnServers: Bool {
        switch edit {
        case .new(let account, _), .rename(_, let account), .delete(_, let account):
            app.account(account)?.kind != .gmail
        case nil: false
        }
    }

    private var nameHint: Text {
        if hasOwnServers {
            return Text("Labels are folders on your mail server: it is made (or renamed) there too.")
        }
        switch edit {
        case .rename: return Text("Renamed in Gmail too. Use “Parent/Child” to put it inside another label.")
        case .new(_, .some): return Text("It is added to this conversation and to Gmail’s label list. Use “Parent/Child” to nest it.")
        default: return Text("It is added to Gmail’s label list. Use “Parent/Child” to put it inside another label.")
        }
    }

    private func save() {
        let edit = edit
        let name = name
        self.edit = nil
        Task {
            switch edit {
            case .new(let account, let thread):
                guard let label = await app.createLabel(name, in: account), let thread else { return }
                if !app.labelIDs(of: thread).contains(label.id) { await app.toggleLabel(label, on: thread) }
            case .rename(let label, let account):
                await app.renameLabel(label, to: name, in: account)
            default:
                break
            }
        }
    }

    // MARK: Deleting

    private var isDeleting: Binding<Bool> {
        Binding {
            if case .delete = edit { true } else { false }
        } set: { if !$0, !isNaming.wrappedValue { edit = nil } }
    }

    private var deleteTitle: Text {
        if case .delete(let label, _) = edit { Text("Delete “\(label.name)”?") } else { Text(verbatim: "") }
    }

    private var deleteMessage: Text {
        hasOwnServers
            ? Text("The folder is removed from your mail server. The mail it was on stays where it is.")
            : Text("The label is removed from Gmail. The mail it was on stays where it is.")
    }

    private func delete() {
        guard case .delete(let label, let account) = edit else { return }
        edit = nil
        Task { await app.deleteLabel(label, in: account) }
    }
}

extension View {
    /// Asks for a label's name, or to confirm deleting it, while `edit` is set.
    func labelEditing(_ edit: Binding<LabelEdit?>) -> some View {
        modifier(LabelEditing(edit: edit))
    }
}
