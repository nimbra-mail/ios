#if DEBUG
import Foundation
import NimbraCore

/// The demo launch's composer and toasts, for screenshots of the 04, 13 and 14 frames:
/// `-Compose new|reply|attachments|suggestions|from|send-later`, `-Toast undo|offline`
/// (with `-Offline YES` the sample engine is offline: sends wait for the connection).
extension AppModel {
    /// What `-Compose` asks the composer to show at launch.
    nonisolated enum ComposeDemo: String {
        case new, reply, attachments, suggestions, from
        case sendLater = "send-later"

        static var launch: ComposeDemo? {
            UserDefaults.standard.string(forKey: "Compose").flatMap(ComposeDemo.init(rawValue:))
        }
    }

    func startComposeDemo() {
        if let demo = ComposeDemo.launch {
            let composer = Composer(kind: demo == .new ? .new : .reply, from: SampleData.work.id)
            if demo != .new {
                composer.to = [SampleData.mira.email]
                composer.subject = "Re: Q4 launch plan"
                let text = "Looks great, signing off now. One note on slide 14: let’s keep the annual discount at 20%."
                composer.written = "<div>\(text)</div>"
                composer.text = text
            }
            composer.signature = .init(id: "sample-signature", html: "<div>Luan Gjokaj</div><div>UX Engineer &amp; Designer</div><div>nimbra.me</div>")
            if demo == .attachments {
                composer.files = [
                    .init(name: "Q4-Launch-Plan.pdf", mime: "application/pdf", bytes: Data(count: 4_200_000)),
                    .init(name: "Pricing-tiers.png", mime: "image/png", bytes: Data(count: 860_000)),
                ]
            }
            if demo == .suggestions { composer.typingTo = "jo" }
            composer.kind = demo == .new ? .new : .reply
            self.composer = composer
        }
        switch UserDefaults.standard.string(forKey: "Toast") {
        case "undo":
            show(Toast(icon: .send, text: String(localized: "Sending…"), action: .undoSend(UUID()), duration: nil))
        case "offline":
            isOffline = true
            waitingMessages[SampleData.work.id] = 2
            // Two messages wait in the sample engine, so the catch-ups keep them waiting.
            for subject in ["Q4 launch plan", "Coffee next week?"] {
                let message = OutgoingMessage(to: SampleData.mira.email, cc: "", bcc: "", subject: subject, body: "", html: nil, files: [], kept: [], reply: nil)
                let send = SampleSend(account: SampleData.work.id, message: message, deliverAtMs: 0) { .waitingForConnection }
                host?.engine.waitForConnection(send: send)
            }
            show(Toast(icon: .wifiOff, text: String(localized: "You’re offline. It’s sent when you’re back."), duration: nil))
        default:
            break
        }
    }
}
#endif
