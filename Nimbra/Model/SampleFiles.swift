import UIKit

/// Files the sample engine hands out in place of downloads: drawn here, never fetched.
nonisolated enum SampleFiles {
    /// A one-page PDF with the file's name on it.
    static func pdf(title: String) -> Data {
        let page = CGRect(x: 0, y: 0, width: 612, height: 792)
        return UIGraphicsPDFRenderer(bounds: page).pdfData { context in
            context.beginPage()
            let text = NSAttributedString(string: title, attributes: [.font: UIFont.systemFont(ofSize: 28, weight: .semibold)])
            text.draw(at: CGPoint(x: 56, y: 72))
        }
    }

    /// A wide picture in the brand's colours, as a PNG.
    static func picture() -> Data {
        let size = CGSize(width: 520, height: 120)
        return UIGraphicsImageRenderer(size: size).pngData { context in
            let colors = [UIColor(resource: .accentRose).cgColor, UIColor(resource: .accentSky).cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
                context.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])
            }
        }
    }
}
