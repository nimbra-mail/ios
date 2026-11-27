import Foundation

/// A style the formatting bar toggles.
nonisolated enum SignatureStyle: CaseIterable, Identifiable {
    case bold, italic, underline

    var id: Self { self }

    var icon: NimbraIcon {
        switch self {
        case .bold: .bold
        case .italic: .italic
        case .underline: .underline
        }
    }

    var label: LocalizedStringResource {
        switch self {
        case .bold: "Bold"
        case .italic: "Italic"
        case .underline: "Underline"
        }
    }
}
