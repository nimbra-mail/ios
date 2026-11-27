# Architecture

Nimbra for iOS is a SwiftUI app over [nimbra-core](https://github.com/nimbra-mail/core), the mail engine both Nimbra
apps share. The engine does the mail: accounts, sign-in, servers, the encrypted store, listing, sending. The app
shows it and keeps it current.

```
Features (SwiftUI screens)          Nimbra/Features/*, Nimbra/Design/*
        │  read state, call methods
AppModel (@Observable, main actor)  Nimbra/Model/AppModel*.swift
        │  engine(for:report:work:)
EngineHost                          Nimbra/Engine/EngineHost.swift
        │  BlockingWork: engine threads, off the main actor and the cooperative pool
MailEngine (protocol)               Nimbra/Engine/MailEngine.swift
        │
NimbraCore.Engine (Rust, UniFFI)    + KeychainSecretStore, SystemDNSResolver, EngineFolders
```

## The engine layer (`Nimbra/Engine/`)

- **`EngineHost`** owns the engine for the app's lifetime. `EngineHost.start()` opens it off the main actor in the
  app's own folders, with the app's Keychain and the system's DNS resolver; the engine keeps its folders for the
  process's life, so there is one per process. Every call goes through `call { engine in … }`, which runs it on an
  engine thread and maps what it throws to a `MailError`.
- **`BlockingWork`** runs those calls on a concurrent dispatch queue of their own. Every engine method blocks, some for
  as long as a server takes (a minute at most) and a change watch for its whole interval. Swift's cooperative pool
  must never block, so `Task.detached` would let a few slow servers stall the app; a serial executor would make a quick
  read of the store wait behind a slow refresh. The engine guards its own state, so calls run side by side.
- **`MailEngine`** is the list of engine calls the app makes, with `Engine`'s exact signatures (`Engine` conforms on its
  own). The app never names `Engine` elsewhere, so previews, the demo and tests run on `SampleEngine` or a test fake.
- **`MailError`** is what the app shows: signed out, offline, not found, the Keychain, the engine's own words for the
  rest, and `notConfigured` for a sign-in this build has no client id for.
- **`KeychainSecretStore`**: generic passwords under one service (`com.riangle.nimbra`), the engine's service and
  account as the item's account, after first unlock, this device only, never synchronized. `NotFound` and real errors
  stay apart; errors carry a status code only, and nothing is logged.
- **`SystemDNSResolver`**: MX lookups through `DNSServiceQueryRecord` with a five-second timeout. No DNS-over-HTTPS.
- **`EngineFolders`**: `Application Support/Nimbra` (file protection `completeUntilFirstUserAuthentication`, excluded
  from backup) and `Caches/Nimbra`.
- **`OAuthConfig`**: the client ids from Info.plist (`Config/OAuth.xcconfig`), checked for shape, and each provider's
  redirect.

## AppModel (`Nimbra/Model/`)

One `@Observable` `AppModel` in the environment. Its stored state is in `AppModel.swift`; each area is an extension in
its own file:

| File                          | What                                                                        |
| ----------------------------- | --------------------------------------------------------------------------- |
| `AppModel.swift`              | State, `start()`, `engine(for:report:work:)`, `handle(_:)`, `reached(_:)`    |
| `AppModel+Accounts.swift`     | Accounts, the one shown, default, remove, Google/Microsoft sign-in, IMAP     |
| `AppModel+Mailboxes.swift`    | Listings: cached first, `refresh`, `loadMore`, counts, the split inbox       |
| `AppModel+Actions.swift`      | Read, star, Done, snooze: shown at once, undone when refused                 |
| `AppModel+Reading.swift`      | `open` (Preferences, messages cached first, mark read when due), files, remote images, Trash, Move to Inbox |
| `AppModel+Compose.swift`      | The composer (`Composer`): opening it, drafts saved once typing pauses, signatures, suggestions |
| `AppModel+ComposeHooks.swift` | What other areas call: `compose`, `startAnswer`, `openDraft`, `openMailto`, `startUnsubscribe`, `catchUpOutbox`, `outboxDeadline` |
| `AppModel+Sending.swift`      | Send (held for the undo time, Undo in the toast), waiting for the connection, Send later, the toast (`show(_:undo:)`) |
| `AppModel+Search.swift`       | Search: the device's matches at once, then the server's, a page at a time    |
| `AppModel+AllInboxes.swift`   | All inboxes: every account's inbox merged, a page more as it scrolls         |
| `AppModel+Labels.swift`       | Labels: list, create, rename, delete, put on or take off, Move to            |
| `AppModel+Blocking.swift`     | Block and unblock senders, the blocked list                                  |
| `AppModel+MailboxList.swift`  | Mailboxes' sections and counts, snooze times, the mailbox lists              |
| `AppModel+Refresh.swift`      | `refreshAll`, `stayCurrent` (watch or interval), `flush`                     |
| `AppModel+Presentation.swift` | The add-account sheet and alerts                                             |
| `ImapSetup.swift`             | 10 · IMAP setup's steps (its own `@Observable`, owned by the screen)         |

**Listings.** `listings[ListingKey(account:mailbox:)]` holds a mailbox's threads as far as they are listed. `show(key)`
loads what the device keeps (`cachedThreads`) and then `refresh(key)` brings it up to date (`refreshMailbox`, then the
rows again from the store, the mailboxes and the counts). `loadMore(key)` adds the next page. Any mailbox works the
same way: Starred, Sent or a label is `show(ListingKey(account: id, mailbox: .starred))`.

**Split inbox.** An account has it when the engine lists `.split` mailboxes (Gmail). The Inbox then shows
`split.mailbox` (Primary, Updates, Promotions, Social) with the unread counts of Gmail's category labels; any other
account shows `.inbox` with no chips.

**Errors.** `engine(for: account, report: …) { … }` returns nil on failure and hands the error to `handle`: offline sets
`isOffline` (never an alert), a gone sign-in adds the account to `signedOut`, and `report: true` (what a person did)
sets `alert`. `reached(account)` clears both when a call got through to the server.

**Staying current.** `RootView` runs `stayCurrent()` in a `.task` keyed on the scene being active and the account
shown: it refreshes everything, then waits on the account's `ChangeWatch` (or the interval when it cannot watch) and
refreshes again, until the task is cancelled. Going to the background flushes the engine inside a background task.

**Sample data.** `SampleEngine` serves `SampleData` as the engine would. It backs previews
(`AppModel.sample()`), the unit tests' host app, and the debug-only `-SignedIn YES` demo launch for screenshots
(`-Present add-account` or `-Present other-address` also opens that sheet). Someone who signs in never sees it.

## Adding a feature

1. **An engine call.** Add its exact signature from `NimbraCore.swift` to `MailEngine`, then give `SampleEngine` and
   `NimbraTests/FakeEngine` an answer. The compiler lists what is missing.
2. **Model.** Add `AppModel+<Area>.swift` with the methods, and the stored state the area needs in `AppModel.swift`
   (an extension cannot store). Call the engine through `engine(for:report:work:)`; use `reached` after a call that
   proved the server answers.
3. **Screen.** `Nimbra/Features/<Screen>/`, built from its Figma frame with the components in `Nimbra/Design/`.
4. **Tests.** Swift Testing in `NimbraTests`, on `FakeEngine` (`Fixture.app(engine)`).

What each upcoming area starts from:

- **Reading** (done): HTML in a locked-down `WKWebView` (`Features/Thread/Web/`: a Content-Security-Policy that
  blocks everything remote, the page's JavaScript off, a content rule list, no navigation, a non-persistent store;
  remote images only through the `nimbra-image:` scheme, which the engine's `fetchRemoteImage` answers, once allowed;
  the Mac's `dark_mail.js` in a content world of its own), the reader (`blocks`) otherwise, attachments in protected
  temporary files for Quick Look and sharing, and `markReadAfterMs`.
- **Compose and sending** (done): the composer (`Composer`, `Features/Compose/`) opens from the tab bar, an answer
  (`startAnswer`), a draft (`draftForThread`) or a `mailto:` link, and saves itself (`saveDraft`). Send holds the
  message for the undo time (`queueSend`, `OutgoingSend`) with Undo in the toast; offline it waits and goes with
  `catchUp`, and an earlier run's mail comes back through `unsent`. Send later is `scheduleSend` and `sendDue`;
  `suggestContacts` fills the recipient fields.
- **Mailboxes**: `mailboxes[account]` already lists them; `show(ListingKey(…))` lists any of them.
  `cachedAllInboxes` and `allInboxes` for All inboxes.
- **Snooze and notifications**: `snooze` and `snoozedThreads` are wired; `wakeDue`, `pendingWork`, `checkForChanges`,
  `badgeCount`, and background tasks.
- **Settings**: `preferences`/`setPreferences`, signatures, `makeDefault`, `removeAccount`, signing in again
  (`signIn(with:again:)` for Google and Microsoft).
