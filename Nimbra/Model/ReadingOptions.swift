import Foundation
import NimbraCore

/// The Preferences reading follows, as the Mac reads them: the original view or the reader,
/// remote images, darkened emails, and when an opened thread counts as read.
nonisolated struct ReadingOptions: Equatable, Sendable {
    /// Mail with HTML opens in its original formatting (the web view), else in the reader.
    var originalView = true
    /// Remote images load in the original view without asking.
    var loadImages = true
    /// In dark mode, light emails get a dark page.
    var darkEmails = true
    /// How long a thread stays open before it counts as read; nil: only when the person says so.
    var markReadAfter: Duration? = .zero

    init() {}

    init(_ preferences: Preferences, markReadAfterMs: UInt32?) {
        originalView = preferences.originalView
        loadImages = preferences.loadImages
        darkEmails = preferences.darkEmails
        markReadAfter = markReadAfterMs.map { .milliseconds(Int64($0)) }
    }
}
