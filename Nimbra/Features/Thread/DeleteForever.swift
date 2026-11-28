import AuthenticationServices
import SwiftUI

extension View {
    /// Delete forever, as the Mac asks it: a destructive confirmation first, then, when
    /// Gmail needs its full mail access, the ask for it (Google's page), after which the
    /// thread is deleted. `thread` is the one asked about; set it to start.
    func deletesForever(_ thread: Binding<MailThread.ID?>) -> some View {
        modifier(DeleteForeverAlerts(thread: thread))
    }
}

private struct DeleteForeverAlerts: ViewModifier {
    @Binding var thread: MailThread.ID?
    @Environment(AppModel.self) private var app
    @Environment(\.webAuthenticationSession) private var webAuthenticationSession
    /// The thread waiting for Google's full mail access.
    @State private var needsAccess: MailThread.ID?

    func body(content: Content) -> some View {
        content
            .alert("Delete forever?", isPresented: isPresent($thread), presenting: thread) { id in
                Button("Delete forever", role: .destructive) { delete(id) }
                Button("Cancel", role: .cancel) {}
            } message: { _ in
                Text("It is deleted from the server for good. This can’t be undone.")
            }
            .alert("One more permission", isPresented: isPresent($needsAccess), presenting: needsAccess) { id in
                Button("Continue") {
                    Task {
                        guard await app.grantFullAccess(to: id.account, authenticate: webAuthenticationSession.authenticator) else { return }
                        delete(id)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: { _ in
                Text("Deleting for good needs Google’s full mail access, which Nimbra does not ask for until it is needed. Nothing is deleted until you allow it.")
            }
    }

    private func delete(_ id: MailThread.ID) {
        Task {
            if await app.deleteForever(id) == .needsFullAccess { needsAccess = id }
        }
    }

    private func isPresent(_ value: Binding<MailThread.ID?>) -> Binding<Bool> {
        Binding(get: { value.wrappedValue != nil }, set: { if !$0 { value.wrappedValue = nil } })
    }
}
