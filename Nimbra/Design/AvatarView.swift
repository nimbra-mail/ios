import SwiftUI

/// A person's initials on their tone's gradient, as the desktop draws them.
struct AvatarView: View {
    let person: Person
    var size: CGFloat = 40

    var body: some View {
        Circle()
            .fill(person.tone.gradient)
            .frame(width: size, height: size)
            .overlay {
                Text(verbatim: person.initials)
                    .font(.custom("Geist-SemiBold", fixedSize: size * 0.36))
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)
    }
}
