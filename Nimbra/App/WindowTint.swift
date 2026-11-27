import SwiftUI
import UIKit

extension View {
    /// Gives the app's windows the accent (`AccentColor`) as their tint.
    ///
    /// SwiftUI tints the window with the asset catalog's accent (`NSAccentColorName`), but
    /// not once the scene has a `.backgroundTask` (the background refresh): the window then
    /// keeps UIKit's system blue, and so does everything that takes its color from the
    /// window, `Color.accentColor` in Liquid Glass (the tab bar) and in the screens a sheet
    /// pushes among it. Set on the window, it reaches all of them.
    func tintsWindows() -> some View {
        onAppear {
            for scene in UIApplication.shared.connectedScenes {
                guard let scene = scene as? UIWindowScene else { continue }
                for window in scene.windows { window.tintColor = UIColor(resource: .accent) }
            }
        }
    }
}
