import SwiftUI

/// A person's initials on their tone's gradient, as the desktop draws them.
struct AvatarView: View {
    let person: Person
    var size: CGFloat = 40
    /// The initials' size, when it is not the one that goes with `size` (a header's 44 pt
    /// avatar keeps the 13.5 pt of a 36 pt one).
    var initialsSize: CGFloat?

    var body: some View {
        Circle()
            .fill(person.tone.gradient)
            .frame(width: size, height: size)
            .overlay {
                Text(verbatim: person.initials)
                    .font(.custom("Geist-SemiBold", fixedSize: initialsSize ?? size * 0.36))
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)
    }
}
