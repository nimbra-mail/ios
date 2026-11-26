import SwiftUI

/// Welcome until an account is connected, then the tabs. Keeps the mail current while
/// the app is in front, and presents adding an account and alerts.
struct RootView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var app = app
        Group {
            switch app.phase {
            case .launching: Color.bgList.ignoresSafeArea()
            case .welcome: WelcomeView()
            case .signedIn: MainTabView()
            }
        }
        .animation(.smooth, value: app.phase)
        .task { await app.start() }
        // Starts over when the app comes back to the front or another account is shown;
        // cancelled when it leaves.
        .task(id: Foreground(isActive: scenePhase == .active, phase: app.phase, account: app.accountID)) {
            guard scenePhase == .active else { return }
            await app.stayCurrent()
        }
        .sheet(item: $app.addingAccount) { start in
            AddAccountSheet(start: start)
        }
        .alert(app.alert?.title ?? "", isPresented: $app.showsRootAlert, presenting: app.alert) { _ in
            Button("OK", role: .cancel) {}
        } message: { error in
            Text(verbatim: error.message)
        }
    }

    private struct Foreground: Equatable {
        let isActive: Bool
        let phase: AppModel.Phase
        let account: Account.ID?
    }
}
