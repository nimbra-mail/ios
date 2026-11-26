import Foundation
import Testing
@testable import Nimbra

@MainActor
struct AppModelTests {
    @Test func inboxIsNewestFirstAndLeavesSnoozedOut() throws {
        let app = AppModel(phase: .signedIn)
        let inbox = app.inbox(.important)
        #expect(inbox.map(\.date) == inbox.map(\.date).sorted(by: >))
        let first = try #require(inbox.first)
        app.snooze(first.id, until: .now.addingTimeInterval(3600))
        #expect(!app.inbox(.important).contains { $0.id == first.id })
        #expect(app.snoozed.map(\.id) == [first.id])
    }

    @Test func doneTakesTheThreadOut() throws {
        let app = AppModel(phase: .signedIn)
        let first = try #require(app.inbox(.important).first)
        app.markDone(first.id)
        #expect(app.thread(first.id) == nil)
    }

    @Test func readingCountsDown() throws {
        let app = AppModel(phase: .signedIn)
        let before = app.unreadCount(.important)
        let firstUnread = app.inbox(.important).first(where: \.isUnread)
        let unread = try #require(firstUnread)
        app.markRead(unread.id)
        #expect(app.unreadCount(.important) == before - 1)
        app.markAllRead(.important)
        #expect(app.unreadCount(.important) == 0)
    }

    @Test func searchNeedsEveryWord() {
        let app = AppModel(phase: .signedIn)
        #expect(app.search("").isEmpty)
        #expect(app.search("launch deck").map(\.subject) == ["Q4 launch plan, final review"])
        #expect(app.search("launch nowhere").isEmpty)
    }
}
