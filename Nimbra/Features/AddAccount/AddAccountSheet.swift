import SwiftUI

/// The add-account sheet: the providers (09), and another address's setup (10) on top of
/// them, or on its own from Welcome.
struct AddAccountSheet: View {
    let start: AddAccountStart
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var showsSetup = false

    var body: some View {
        @Bindable var app = app
        Group {
            if start == .otherAddress {
                ImapSetupView(leading: .close, leave: { dismiss() }, done: { dismiss() })
            } else if showsSetup {
                ImapSetupView(leading: .back, leave: { withAnimation(.smooth) { showsSetup = false } }, done: { dismiss() })
                    .transition(.move(edge: .trailing))
            } else {
                AddAccountView(close: { dismiss() }, otherAddress: { withAnimation(.smooth) { showsSetup = true } })
                    .transition(.move(edge: .leading))
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color.surfaceRaised)
        .presentationBackground(Color.surfaceRaised)
        .presentationDragIndicator(.visible)
        .alert(app.alert?.title ?? "", isPresented: $app.showsAlert, presenting: app.alert) { _ in
            Button("OK", role: .cancel) {}
        } message: { error in
            Text(verbatim: error.message)
        }
    }
}
