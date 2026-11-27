import SwiftUI
import UIKit

extension View {
    /// Applies the theme picked in Settings (`Appearance`) to every window, sheets
    /// included. Set on the window, as `preferredColorScheme` only reaches the nearest
    /// presentation and does not go back to the system's reliably.
    func appliesAppearance() -> some View {
        modifier(AppearanceModifier())
    }
}

private struct AppearanceModifier: ViewModifier {
    @AppStorage(Appearance.key) private var appearance = Appearance.system

    func body(content: Content) -> some View {
        content.onChange(of: appearance, initial: true) {
            for scene in UIApplication.shared.connectedScenes {
                guard let scene = scene as? UIWindowScene else { continue }
                for window in scene.windows { window.overrideUserInterfaceStyle = appearance.style }
            }
        }
    }
}
