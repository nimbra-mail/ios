import Foundation
import NimbraCore
import SwiftUI

/// How often Nimbra checks for mail while it is open, as on the Mac.
nonisolated enum CheckInterval: UInt32, CaseIterable, Identifiable, Sendable {
    case tenSeconds = 10
    case thirtySeconds = 30
    case oneMinute = 60
    case fiveMinutes = 300

    var id: Self { self }

    /// The choice a stored number of seconds shows as, by range as the Mac reads it.
    init(seconds: UInt32) {
        self = switch seconds {
        case ...20: .tenSeconds
        case ...45: .thirtySeconds
        case ...150: .oneMinute
        default: .fiveMinutes
        }
    }

    var label: LocalizedStringResource {
        switch self {
        case .tenSeconds: "10 seconds"
        case .thirtySeconds: "30 seconds"
        case .oneMinute: "1 minute"
        case .fiveMinutes: "5 minutes"
        }
    }
}

/// How long a sent message can still be taken back, as on the Mac: "5 seconds" keeps 6, so
/// the toast is up for five whole seconds.
nonisolated enum UndoSendDelay: UInt32, CaseIterable, Identifiable, Sendable {
    case off = 0
    case five = 6
    case ten = 10
    case twenty = 20
    case thirty = 30

    var id: Self { self }

    /// The nearest choice to a stored number of seconds.
    init(seconds: UInt32) {
        self = Self.allCases.min { abs(Int($0.rawValue) - Int(seconds)) < abs(Int($1.rawValue) - Int(seconds)) } ?? .five
    }

    var label: LocalizedStringResource {
        switch self {
        case .off: "Off"
        case .five: "5 seconds"
        case .ten: "10 seconds"
        case .twenty: "20 seconds"
        case .thirty: "30 seconds"
        }
    }
}

nonisolated extension MarkReadChoice: @retroactive Identifiable, @retroactive CaseIterable {
    public var id: Self { self }
    public static var allCases: [MarkReadChoice] { [.open, .delay, .never] }

    var label: LocalizedStringResource {
        switch self {
        case .open: "When opened"
        case .delay: "After 2 seconds"
        case .never: "Manually"
        }
    }
}

/// The app's theme: the iPhone's, or always light or dark. Kept on this device.
nonisolated enum Appearance: String, CaseIterable, Identifiable, Sendable {
    case system, light, dark

    var id: Self { self }

    /// The `@AppStorage` key.
    static let key = "Appearance"

    var label: LocalizedStringResource {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var style: UIUserInterfaceStyle {
        switch self {
        case .system: .unspecified
        case .light: .light
        case .dark: .dark
        }
    }
}

nonisolated extension TextSize: @retroactive Identifiable, @retroactive CaseIterable {
    public var id: Self { self }
    public static var allCases: [TextSize] { [.small, .default, .large, .extraLarge] }

    var label: LocalizedStringResource {
        switch self {
        case .small: "Small"
        case .default: "Default"
        case .large: "Large"
        case .extraLarge: "Extra large"
        }
    }

    /// How much larger than the reading size mail text is drawn. The Mac draws mail at
    /// 13.5, 15, 17 and 19 points; iOS keeps those steps around its own reading size, which
    /// Dynamic Type sets.
    var scale: CGFloat {
        switch self {
        case .small: 13.5 / 15
        case .default: 1
        case .large: 17 / 15
        case .extraLarge: 19 / 15
        }
    }
}
