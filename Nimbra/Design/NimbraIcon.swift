import SwiftUI

/// The Lucide glyphs the Figma kit uses, as template vectors
/// (`Assets.xcassets/Icons`). They take the foreground style.
nonisolated enum NimbraIcon: String {
    case activity
    case alert
    case archive
    case back
    case ban
    case bell
    case bold
    case brush
    case bullets
    case calendar
    case check
    case clip
    case clock
    case compose
    case copy
    case done
    case down
    case draft
    case eye
    case file
    case folder
    case forward
    case image
    case info
    case inbox
    case italic
    case link
    case list
    case loader
    case key
    case lock
    case mail
    case moon
    case more
    case news
    case next
    case numbers
    case pen
    case plus
    case quote
    case reload
    case replyAll = "reply-all"
    case reply
    case search
    case send
    case sidebar
    case sort
    case sparkles
    case star
    case sun
    case tag
    case trash
    case type
    case underline
    case undo
    case up
    case user
    case updown
    case users
    case wifiOff = "wifi-off"
    case x
    case zap
}

/// A kit icon at a size in points, scaling with Dynamic Type.
struct Icon: View {
    let icon: NimbraIcon
    @ScaledMetric private var size: CGFloat

    init(_ icon: NimbraIcon, size: CGFloat = 20) {
        self.icon = icon
        _size = ScaledMetric(wrappedValue: size)
    }

    var body: some View {
        Image(icon.rawValue)
            .resizable()
            .renderingMode(.template)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
