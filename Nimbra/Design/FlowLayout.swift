import SwiftUI

/// Lays its views out in lines at their ideal widths, wrapping when a line is full; the
/// last view takes the rest of its line (the field typed in after the chips).
struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    var lineSpacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let lines = arrange(width: width, subviews: subviews)
        let height = lines.map(\.height).reduce(0, +) + lineSpacing * CGFloat(max(lines.count - 1, 0))
        return CGSize(width: proposal.width ?? (lines.map(\.width).max() ?? 0), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for line in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for (index, width) in zip(line.indices, line.widths) {
                let isLast = index == subviews.indices.last
                let placed = isLast ? max(width, bounds.maxX - x) : width
                let size = subviews[index].sizeThatFits(.init(width: placed, height: nil))
                subviews[index].place(
                    at: CGPoint(x: x, y: y + (line.height - size.height) / 2),
                    proposal: .init(width: placed, height: size.height)
                )
                x += placed + spacing
            }
            y += line.height + lineSpacing
        }
    }

    private struct Line {
        var indices: [Int] = []
        var widths: [CGFloat] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Line] {
        var lines: [Line] = []
        var line = Line()
        for index in subviews.indices {
            let ideal = subviews[index].sizeThatFits(.unspecified)
            let itemWidth = min(ideal.width, width)
            if !line.indices.isEmpty, line.width + spacing + itemWidth > width {
                lines.append(line)
                line = Line()
            }
            line.width += (line.indices.isEmpty ? 0 : spacing) + itemWidth
            line.height = max(line.height, ideal.height)
            line.indices.append(index)
            line.widths.append(itemWidth)
        }
        if !line.indices.isEmpty { lines.append(line) }
        return lines
    }
}
