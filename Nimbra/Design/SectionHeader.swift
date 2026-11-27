import SwiftUI

/// The kit's Section Header: an overline above a grouped list.
struct SectionHeader: View {
    let title: LocalizedStringKey

    init(_ title: LocalizedStringKey) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .nimbraText(.overline)
            .foregroundStyle(Color.textFaint)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 4)
            .padding(.top, 10)
            .accessibilityAddTraits(.isHeader)
    }
}
