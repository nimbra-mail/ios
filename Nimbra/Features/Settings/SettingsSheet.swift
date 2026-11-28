import SwiftUI

/// 08 · Settings as a page sheet, opened from the account photo in Inbox: its screens are
/// pushed inside it. It shows its own alerts (the root's cannot show over it).
struct SettingsSheet: View {
    @Environment(AppModel.self) private var app
    @State private var path: [SettingsRoute] = SettingsSheet.pathAtLaunch

    var body: some View {
        @Bindable var app = app
        NavigationStack(path: $path) {
            SettingsView()
                .navigationDestination(for: SettingsRoute.self) { route in
                    switch route {
                    case .account(let id): AccountSettingsView(accountID: id)
                    case .signature(let account, let id): SignatureEditorView(accountID: account, signatureID: id)
                    case .notifications: NotificationSettingsView()
                    case .blockedSenders: BlockedSendersView()
                    case .appearance: AppearanceSettingsView()
                    case .privacy: PrivacySettingsView()
                    case .about: AboutView()
                    }
                }
        }
        .presentationBackground(Color.surfaceRaised)
        .presentationDragIndicator(.visible)
        .task {
            await app.loadPreferences()
            await app.loadAllBlocked()
        }
        .alert(app.alert?.title ?? "", isPresented: $app.showsAlert, presenting: app.alert) { _ in
            Button("OK", role: .cancel) {}
        } message: { error in
            Text(verbatim: error.message)
        }
    }

    private static var pathAtLaunch: [SettingsRoute] {
        #if DEBUG
        SettingsRoute.atLaunch
        #else
        []
        #endif
    }
}
