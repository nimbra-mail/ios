import SwiftUI

/// Microsoft's four squares, in their own colors.
struct MicrosoftLogo: View {
    var size: CGFloat = 20

    var body: some View {
        let square = size * 0.425
        let gap = size * 0.05
        Grid(horizontalSpacing: gap, verticalSpacing: gap) {
            GridRow {
                Rectangle().fill(Color(red: 0.949, green: 0.314, blue: 0.133))
                Rectangle().fill(Color(red: 0.498, green: 0.729, blue: 0))
            }
            GridRow {
                Rectangle().fill(Color(red: 0, green: 0.643, blue: 0.937))
                Rectangle().fill(Color(red: 1, green: 0.725, blue: 0))
            }
        }
        .frame(width: square * 2 + gap, height: square * 2 + gap)
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
