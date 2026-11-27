import SwiftUI

/// A Footnote under a grouped list: what its rows do, in text/tertiary.
struct GroupFootnote: View {
    let text: Text

    init(_ text: LocalizedStringKey) { self.text = Text(text) }
    init(_ text: Text) { self.text = text }

    var body: some View {
        text
            .nimbraText(.footnote)
            .foregroundStyle(Color.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            .padding(.top, 2)
            .padding(.bottom, 6)
    }
}
