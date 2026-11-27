import SwiftUI

extension Tone {
    /// The tone as a pill's dot: an account's tag in All inboxes.
    var dot: Color {
        switch self {
        case .violet: .accentColor
        case .rose: .accentRose
        case .amber: .accentAmber
        case .mint: .accentMint
        case .sky: .accentSky
        case .graphite: .textTertiary
        }
    }
}
