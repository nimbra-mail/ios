import SwiftUI

/// How the signature is edited: as text with formatting, as its HTML, or seen as sent.
nonisolated enum SignatureEditorMode: CaseIterable, Identifiable, Hashable {
    case text, html, preview

    var id: Self { self }

    var label: LocalizedStringResource {
        switch self {
        case .text: "Text"
        case .html: "HTML"
        case .preview: "Preview"
        }
    }
}
