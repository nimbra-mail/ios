import SwiftUI

/// The three tabs under the floating glass tab bar, and the composer it opens.
struct MainTabView: View {
    @Environment(AppModel.self) private var app
    @State private var tab = AppTab.inbox
    // MARK: Reading
    /// A screen pushed over a tab (a thread) has its own bar at the bottom.
    @State private var hidesTabBar = false

    var body: some View {
        Group {
            switch tab {
            case .inbox: InboxView()
            case .snoozed: SnoozedView()
            case .mailboxes: MailboxesView()
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                // MARK: Sending
                if let toast = app.toast {
                    ToastView(toast: toast) { action in
                        Task { await app.run(action) }
                    }
                    .id(toast.id)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                if !hidesTabBar {
                    TabBar(selection: $tab) { Task { await app.compose() } }
                }
            }
            .animation(.smooth(duration: 0.25), value: app.toast)
        }
        .onPreferenceChange(HidesTabBar.self) { hidesTabBar = $0 }
    }
}
