import SwiftUI

/// A subject in the serif title, the words after its last comma in italic, as
/// the desktop sets it ("Q4 launch plan, *final review*").
struct SubjectTitle: View {
    let subject: String

    var body: some View {
        title
            .nimbraText(.title)
            .foregroundStyle(Color.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }

    private var title: Text {
        guard let comma = subject.range(of: ", ", options: .backwards) else {
            return Text(verbatim: subject)
        }
        let head = String(subject[..<comma.upperBound])
        let tail = String(subject[comma.upperBound...])
        return Text("\(Text(verbatim: head))\(Text(verbatim: tail).font(NimbraTextStyle.titleItalic.font))")
    }
}
