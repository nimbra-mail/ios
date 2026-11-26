import SwiftUI

/// An avatar's colors, the same six the desktop app uses.
nonisolated enum Tone: CaseIterable, Hashable {
    case violet, rose, amber, mint, sky, graphite

    /// Light at the top left, deep at the bottom right.
    var gradient: LinearGradient {
        let (top, bottom): (UInt32, UInt32) = switch self {
        case .violet: (0x9B8CFF, 0x5B47E0)
        case .rose: (0xFF9CC8, 0xE0457F)
        case .amber: (0xFFD08A, 0xF07D2E)
        case .mint: (0x8BF0C7, 0x16A979)
        case .sky: (0x9DD8FF, 0x2F7FE0)
        case .graphite: (0x6D6C78, 0x2A2A33)
        }
        return LinearGradient(colors: [Color(hex: top), Color(hex: bottom)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// The same tone for the same name, every time.
    static func `for`(_ name: String) -> Tone {
        let sum = name.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return allCases[sum % allCases.count]
    }
}

private extension Color {
    nonisolated init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
