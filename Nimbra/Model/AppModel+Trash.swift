import Foundation
import NimbraCore

/// What Trash adds to a thread, as on the Mac: Delete forever (asked first, no undo), and
/// for a Gmail account's thread, Open in Gmail.
extension AppModel {
    /// How Delete forever went.
    nonisolated enum DeleteOutcome: Equatable, Sendable {
        case deleted
        /// Gmail needs its full mail access first (`grantFullAccess`); nothing was deleted.
        case needsFullAccess
        /// Refused or offline; said in an alert, and the thread is listed again.
        case failed
    }

    /// Deletes a thread for good, from the server too: it leaves every list at once and
    /// comes back when the server refuses. Already gone counts as deleted. Network.
    @discardableResult
    func deleteForever(_ id: MailThread.ID) async -> DeleteOutcome {
        guard let host else { return .failed }
        let before = (listings, opened, searchResults)
        remove(id)
        do throws(MailError) {
            try await host.call { try $0.deleteThread(accountId: id.account, threadId: id.thread) }
        } catch .notFound {
            // Gone from the server already: deleted all the same.
        } catch .needsFullAccess {
            (listings, opened, searchResults) = before
            return .needsFullAccess
        } catch {
            (listings, opened, searchResults) = before
            handle(error, account: id.account, report: true)
            return .failed
        }
        reached(id.account)
        snoozedThreads[id.account]?.removeAll { $0.id == id }
        await loadCachedCounts(id.account)
        show(Toast(icon: .trash, text: String(localized: "Deleted forever")))
        return .deleted
    }

    /// Signs the account in again on Google's page, asking for the full mail access that
    /// deleting for good needs. Whether it was given.
    func grantFullAccess(to account: Account.ID, authenticate: WebAuthenticator) async -> Bool {
        await signIn(with: .google, again: account, fullAccess: true, authenticate: authenticate)
    }

    /// The thread in Gmail on the web, signed in as its own account (`authuser`), as the
    /// Mac opens it. Nil for another kind of account, or an id or address that is not
    /// plain: neither goes into a link unchecked.
    func gmailURL(for id: MailThread.ID) -> URL? {
        guard let account = account(id.account), account.kind == .gmail,
              !id.thread.isEmpty, id.thread.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }) else { return nil }
        let email = account.email
        let plain = email.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || "@.-_+".contains($0)) }
        let user = plain ? "?authuser=" + email.replacingOccurrences(of: "@", with: "%40").replacingOccurrences(of: "+", with: "%2B") : ""
        return URL(string: "https://mail.google.com/mail/\(user)#all/\(id.thread)")
    }
}
