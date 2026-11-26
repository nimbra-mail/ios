import SwiftUI

extension ShapeStyle where Self == LinearGradient {
    /// The desktop's primary fill (Send, Compose): violet into rose.
    static var brand: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.592, green: 0.533, blue: 1), Color(red: 1, green: 0.533, blue: 0.741)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}
