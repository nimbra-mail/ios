import SwiftUI

// Transitional, until Reading's ThreadView calls `AppModel.startAnswer(_:to:)` (its own
// sheet with `ComposeView(draft:)` goes then, and so do this file and `ComposeDraft`).
extension ComposeView {
    /// The old sample reply or forward: handed over to the app's composer at once.
    init(draft: ComposeDraft) {
        let composer = Composer(kind: draft.subject.hasPrefix("Fwd: ") ? .forward : .reply, from: "")
        composer.to = draft.to
        composer.subject = draft.subject
        self.init(composer: composer)
    }
}
