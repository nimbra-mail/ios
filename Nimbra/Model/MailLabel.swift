import SwiftUI

/// One of an account's own labels (IMAP: a folder), in the engine's order.
nonisolated struct MailLabel: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    /// Its place in the list, which picks its tint.
    let index: Int

    /// The tint of its tag, by place, as the Mac tints its labels (violet, amber, rose,
    /// sky, mint, then again).
    @MainActor var tint: Color {
        switch index % 5 {
        case 0: .accentColor
        case 1: .accentAmber
        case 2: .accentRose
        case 3: .accentSky
        default: .accentMint
        }
    }
}
