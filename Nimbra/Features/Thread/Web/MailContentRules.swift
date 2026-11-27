import WebKit

/// A content rule list under the policy: the mail view blocks every load from the web
/// (http, https, WebSocket, FTP) and from files, whatever the document says. Remote images
/// come through `RemoteImageScheme` instead. Compiled once per launch.
enum MailContentRules {
    static let identifier = "com.riangle.nimbra.mail-blocks-remote"

    /// WebKit's rule format has no alternation: one rule per scheme.
    static let json = """
    [
      {"trigger": {"url-filter": "^https?:"}, "action": {"type": "block"}},
      {"trigger": {"url-filter": "^wss?:"}, "action": {"type": "block"}},
      {"trigger": {"url-filter": "^ftp:"}, "action": {"type": "block"}},
      {"trigger": {"url-filter": "^file:"}, "action": {"type": "block"}}
    ]
    """

    private static var compiling: Task<WKContentRuleList?, Never>?

    /// The compiled list; nil when WebKit could not compile it (the mail view then shows the
    /// reader instead: it never shows mail without the list).
    static func list() async -> WKContentRuleList? {
        if let compiling { return await compiling.value }
        let task = Task { @MainActor () -> WKContentRuleList? in
            try? await WKContentRuleListStore.default()?.compileContentRuleList(forIdentifier: identifier, encodedContentRuleList: json)
        }
        compiling = task
        let list = await task.value
        if list == nil { compiling = nil }
        return list
    }
}
