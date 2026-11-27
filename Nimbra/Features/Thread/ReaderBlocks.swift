import NimbraCore
import SwiftUI

/// A message in the reader: the engine's blocks drawn natively (paragraphs, headings,
/// lists, code, rules, quotes and images), as the Mac's reader. Quoted history is indented
/// with a bar, up to four levels. Remote images show only once allowed (`loadsImages`);
/// until then, a placeholder with their description.
struct ReaderBlocks: View {
    let blocks: [TextBlock]
    let images: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                quoted(block)
            }
        }
        .textSelection(.enabled)
    }

    @ViewBuilder
    private func quoted(_ block: TextBlock) -> some View {
        let depth = Int(min(block.quoteDepth, 4))
        if depth > 0 {
            HStack(spacing: 0) {
                ForEach(0..<depth, id: \.self) { _ in
                    Rectangle()
                        .fill(Color.borderStrong)
                        .frame(width: 2)
                        .padding(.trailing, 12)
                }
                content(block, color: Color.textTertiary)
            }
            .fixedSize(horizontal: false, vertical: true)
        } else {
            content(block, color: Color.textSecondary)
        }
    }

    @ViewBuilder
    private func content(_ block: TextBlock, color: Color) -> some View {
        switch block.kind {
        case .paragraph:
            Text(ReaderText.attributed(block))
                .nimbraText(.reading)
                .foregroundStyle(color)
        case .heading:
            Text(ReaderText.attributed(block))
                .nimbraText(.headline)
                .foregroundStyle(Color.textPrimary)
                .accessibilityAddTraits(.isHeader)
        case .listItem(let marker, let depth):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(verbatim: marker)
                    .nimbraText(.reading)
                    .foregroundStyle(Color.textTertiary)
                Text(ReaderText.attributed(block))
                    .nimbraText(.reading)
                    .foregroundStyle(color)
            }
            .padding(.leading, CGFloat(min(depth, 6)) * 16)
        case .code:
            ScrollView(.horizontal) {
                Text(verbatim: block.text)
                    .nimbraText(.mono)
                    .foregroundStyle(color)
                    .padding(12)
            }
            .background(Color.surfaceHover, in: .rect(cornerRadius: 10))
        case .rule:
            Divider().overlay(Color.borderSubtle)
        case .image(let src, let alt):
            ReaderImage(src: src, alt: alt, loads: images)
        }
    }
}

/// A remote image in the reader, fetched by the engine once allowed; else its description.
private struct ReaderImage: View {
    let src: String
    let alt: String
    let loads: Bool
    @Environment(AppModel.self) private var app
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: image.size.width, alignment: .leading)
                    .accessibilityLabel(Text(verbatim: alt))
                    .accessibilityHidden(alt.isEmpty)
            } else {
                HStack(spacing: 8) {
                    Icon(.image, size: 16)
                    if alt.isEmpty {
                        Text("Image")
                    } else {
                        Text("Image: \(alt)")
                    }
                }
                .nimbraText(.footnote)
                .foregroundStyle(Color.textTertiary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.surfaceHover, in: .rect(cornerRadius: 10))
            }
        }
        .task(id: loads) {
            guard loads, image == nil, let data = await app.remoteImage(src) else { return }
            image = UIImage(data: data)
        }
    }
}
