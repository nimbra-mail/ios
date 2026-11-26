import SwiftUI

/// Welcome until an account is connected, then the tabs.
struct RootView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        Group {
            switch app.phase {
            case .welcome: WelcomeView()
            case .signedIn: MainTabView()
            }
        }
        .animation(.smooth, value: app.phase)
    }
}
