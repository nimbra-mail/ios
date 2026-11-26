import SwiftUI

/// The `iOS/…` text styles from the Figma file: Geist for the interface,
/// Instrument Serif for titles, Geist Mono for overlines. Each one scales with
/// Dynamic Type relative to the system style it stands in for.
nonisolated enum NimbraTextStyle {
    /// iOS/Large Title: a screen's serif title ("Inbox").
    case largeTitle
    /// iOS/Large Title Italic: the italic word in a large title.
    case largeTitleItalic
    /// iOS/Title: a thread's subject, a sheet's title.
    case title
    /// iOS/Title Italic: the italic words in a title.
    case titleItalic
    /// The Inbox zero headline (64/66).
    case display
    case displayItalic
    /// The line under Inbox zero (20/26, serif italic).
    case quote
    case headline
    case body
    case bodyMedium
    /// iOS/Reading: a message's text, with room between lines.
    case reading
    /// iOS/Sender: a thread row's sender.
    case sender
    case subhead
    case subheadMedium
    case footnote
    case caption
    /// iOS/Tab: a tab bar label.
    case tab
    case mono
    /// iOS/Overline: Geist Mono labels ("TODAY", the date).
    case overline

    var fontName: String {
        switch self {
        case .largeTitle, .title, .display: "InstrumentSerif-Regular"
        case .largeTitleItalic, .titleItalic, .displayItalic, .quote: "InstrumentSerif-Italic"
        case .headline, .sender: "Geist-SemiBold"
        case .bodyMedium, .subheadMedium, .caption, .tab: "Geist-Medium"
        case .body, .reading, .subhead, .footnote: "Geist-Regular"
        case .mono, .overline: "GeistMono-Medium"
        }
    }

    var size: CGFloat {
        switch self {
        case .display, .displayItalic: 64
        case .largeTitle, .largeTitleItalic: 36
        case .title, .titleItalic: 30
        case .quote: 20
        case .headline, .body, .bodyMedium, .reading: 17
        case .sender: 16
        case .subhead, .subheadMedium: 15
        case .footnote: 13
        case .caption, .mono: 12
        case .overline: 11
        case .tab: 10
        }
    }

    var lineHeight: CGFloat {
        switch self {
        case .display, .displayItalic: 66
        case .largeTitle, .largeTitleItalic: 40
        case .title, .titleItalic: 36
        case .reading: 27
        case .quote: 26
        case .body, .bodyMedium: 24
        case .headline: 22
        case .sender: 21
        case .subhead, .subheadMedium: 20
        case .footnote: 18
        case .caption, .mono: 16
        case .overline: 14
        case .tab: 12
        }
    }

    /// Figma's letter spacing (a percentage of the size) in points.
    var tracking: CGFloat {
        let percent: CGFloat = switch self {
        case .display, .displayItalic: -1.5
        case .largeTitle, .largeTitleItalic, .title, .titleItalic: -0.5
        case .headline: -1
        case .body, .bodyMedium, .reading: -0.6
        case .sender: -0.8
        case .subhead, .subheadMedium: -0.4
        case .footnote, .caption: -0.2
        case .quote, .tab, .mono: 0
        case .overline: 8
        }
        return size * percent / 100
    }

    var relativeTo: Font.TextStyle {
        switch self {
        case .display, .displayItalic, .largeTitle, .largeTitleItalic: .largeTitle
        case .title, .titleItalic: .title
        case .quote: .title3
        case .headline: .headline
        case .body, .bodyMedium, .reading: .body
        case .sender: .callout
        case .subhead, .subheadMedium: .subheadline
        case .footnote: .footnote
        case .caption, .mono, .overline: .caption
        case .tab: .caption2
        }
    }

    var font: Font { .custom(fontName, size: size, relativeTo: relativeTo) }
}
