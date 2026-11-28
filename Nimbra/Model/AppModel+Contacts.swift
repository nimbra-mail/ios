import Foundation
import NimbraCore

/// Address suggestions learnt from mail, as the Mac learns them: the engine reads the
/// people of each account's newest sent and received mail a page at a time, with a pause
/// before each page (the provider's quota is the user's). Only while Nimbra is in front:
/// it stops when the app leaves, and carries on from where it got to the next time
/// (the engine keeps what it learnt).
extension AppModel {
    /// Learns each account's contacts in turn until the engine has no more, a pause before
    /// every step. Run it from the scene's `.task`; it ends when cancelled. An account
    /// that is done, or whose step failed other than offline, is left for this run of the
    /// app; offline, the next time in front tries again.
    func learnContacts() async {
        guard phase == .signedIn else { return }
        let seconds = await engine { $0.contactScanPauseSeconds() } ?? 30
        let pause = Duration.seconds(Int(max(seconds, 1)))
        for account in accounts.map(\.id) where !contactsLearnt.contains(account) {
            while true {
                // Also before the first step: the mail being opened goes first.
                do { try await clock.sleep(pause) } catch { return }
                guard let host, accounts.contains(where: { $0.id == account }), !signedOut.contains(account) else { break }
                let more: Bool
                do throws(MailError) {
                    more = try await host.call { try $0.learnContacts(accountId: account) }
                } catch .offline {
                    return
                } catch {
                    contactsLearnt.insert(account)
                    break
                }
                if !more {
                    contactsLearnt.insert(account)
                    break
                }
            }
        }
    }
}
