import SwiftUI

/// Set by a screen pushed over a tab that has its own bar at the bottom (03 · Thread's
/// actions), so the tab bar steps aside while it is shown.
struct HidesTabBar: PreferenceKey {
    static let defaultValue = false

    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}
