<div align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset=".github/assets/icon-dark.png" />
    <img src=".github/assets/icon-light.png" alt="Nimbra" width="128" height="128" />
  </picture>

  <h1>Nimbra for iOS</h1>

  <p><strong>Blazing fast mail. No bloat.</strong></p>

  <p>
    The iPhone companion to <a href="../nimbra-app">Nimbra for Mac</a>, written in SwiftUI with Liquid Glass.<br />
    Split inbox, snooze, signatures per account, and your mail kept on your iPhone.
  </p>

  <p>
    <img src="https://img.shields.io/badge/iOS-26%2B-black?style=flat&logo=apple" alt="iOS 26 or newer" />
    <img src="https://img.shields.io/badge/Swift-6-f05138?style=flat&logo=swift&logoColor=white" alt="Swift 6" />
    <img src="https://img.shields.io/badge/UI-SwiftUI-8b7cff?style=flat" alt="SwiftUI" />
    <img src="https://img.shields.io/badge/status-early-555?style=flat" alt="Early" />
    <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-3da639?style=flat" alt="MIT license" /></a>
  </p>

  <p>
    <a href="#features">Features</a> ·
    <a href="#get-started">Get started</a> ·
    <a href="#privacy-and-security">Privacy</a> ·
    <a href="#development">Development</a> ·
    <a href="CONTRIBUTING.md">Contributing</a>
  </p>
</div>

<p align="center">
  <img src=".github/assets/showcase.png" alt="Nimbra on iPhone: three screens under the line Blazing fast mail, no bloat. A conversation, the inbox with its split inbox chips and the floating glass tab bar, and the mailboxes with every account." />
</p>

## Features

Nimbra for iOS is early: accounts, the inbox and staying current run on the mail engine; reading, writing and the other mailboxes are being built.

- **Your accounts.** Gmail and Google Workspace, Outlook.com and Microsoft 365 through their own sign-in pages, and any other address with its IMAP and SMTP servers, found for you or typed in. Several at once.
- **Split inbox.** A Gmail account's Primary, Updates, Promotions and Social as chips, each with its unread count, and threads under Today and Earlier. Other accounts have one inbox.
- **Threads that read well.** The subject in a serif title, earlier messages folded into one line each, the latest in full with its attachments.
- **One tap for the usual.** Done, Snooze, Reply and Forward float at the bottom of every thread.
- **Snooze and reminders.** Later today, tomorrow, this weekend or next week, each with the time it comes back, or any date and time; **Only if nobody replies** makes it a reminder.
- **Writing.** From any account, recipients as chips, the signature under what you write, and a formatting bar.
- **Every account in one place.** Accounts, the split inbox and the mailboxes in Mailboxes, with their counts.
- **Inbox zero.** The aurora and a line for the day when a category is empty.
- **Liquid Glass and Dynamic Type.** The tab bar, the actions and the formatting bar are the system's glass; text follows the size you set; light and dark throughout.

## Get started

Requirements: a Mac with Xcode 26 or newer and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```sh
xcodegen
open Nimbra.xcodeproj
```

Run the `Nimbra` scheme on an iOS 26 simulator. To sign in with Google or Microsoft, fill in the OAuth client ids first (see [Sign-in](#sign-in)); another address works without them. In a debug build the launch argument `-SignedIn YES` starts on built-in sample mail instead (for screenshots), and `-Present add-account` or `-Present other-address` opens that sheet at launch.

Run `xcodegen` again after adding, moving or removing files: `Nimbra.xcodeproj` is generated from `project.yml` and not committed.

The mail engine, [nimbra-core](https://github.com/nimbra-mail/core), is a Swift package that Xcode resolves from its GitHub release (pinned in `project.yml`), with the engine prebuilt as `NimbraFFI.xcframework`: no Rust needed. To change the engine and the app together, see [Working on the engine](#working-on-the-engine).

## Sign-in

Google and Microsoft sign in on their own pages (OAuth with PKCE, in the system's sign-in sheet), with the app's own client ids. They are public (an iOS client has no secret) but not in the repo: copy the example and fill it in.

```sh
cp Config/OAuth.example.xcconfig Config/OAuth.xcconfig   # gitignored
```

- **Google**: Google Cloud console › APIs & Services › Credentials › an **iOS** OAuth client for the bundle id `com.riangle.nimbra`. Set `GOOGLE_IOS_CLIENT_ID` to its Client ID and `GOOGLE_REVERSED_CLIENT_ID` to its iOS URL scheme (the id reversed, `com.googleusercontent.apps.…`).
- **Microsoft**: Azure portal › App registrations › Nimbra › Authentication › add the mobile redirect URI `msauth.com.riangle.nimbra://auth`. Set `MICROSOFT_CLIENT_ID` to the Application (client) ID.

Run `xcodegen` and build again after changing it. A value left empty (or a build without the file) keeps that button, which then says sign-in isn't set up in this build. The sign-in sheet is ephemeral: it neither reads nor leaves the browser's cookies, so each account is the one you sign in to on the page.

## Working on the engine

To build the app against your own copy of [nimbra-core](https://github.com/nimbra-mail/core) instead of the release, clone it next to this repo, build its XCFramework (this needs Rust, through rustup) and switch to it:

```sh
git clone https://github.com/nimbra-mail/core ../core
../core/scripts/build-ios-core.sh   # again after every change to the engine
scripts/local-core.sh on            # NimbraCore from ../core
scripts/local-core.sh status        # which one Nimbra.xcodeproj uses
scripts/local-core.sh off           # back to the release
```

`on` writes a gitignored `project.local.yml` that includes `project.yml` and replaces the NimbraCore package with `../core`, then generates the project from it; `project.yml` stays as it is. XcodeGen has no optional include, so while it is on, regenerate with `xcodegen --spec project.local.yml` (or run `on` again): a plain `xcodegen` goes back to the release. To take up a new engine release, change `exactVersion` in `project.yml` and run `xcodegen`.

## Privacy and security

- **Your mail stays on your iPhone.** Nimbra will talk straight to your mail provider, with no server of its own in between.
- **Secrets in the Keychain.** Sign-ins and passwords live only in the Keychain (after first unlock, this device only, never synced), and mail in the engine's encrypted store, excluded from backups: never in `UserDefaults`, logs or the repo.
- **Your own resolver.** Finding an address's servers asks the system's DNS, never a DNS-over-HTTPS service.

## Development

<details>
<summary><strong>Tests</strong></summary>

```sh
xcodebuild -project Nimbra.xcodeproj -scheme Nimbra \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

The tests (Swift Testing) are in `NimbraTests`: the app model on a fake engine (listing, paging, actions, offline and signed-out states, sign-in), IMAP setup, error mapping, the OAuth config, the Keychain store (in the simulator), MX records, and the engine's offline calls.

</details>

### Layout

- `project.yml`: the XcodeGen spec (target, iOS 26, Swift 6, build settings)
- `Nimbra/App/`: the app entry, the root view (Welcome or the tabs) and the tab bar
- `Nimbra/Features/`: one folder per screen (Welcome, Add account and IMAP setup, Inbox, Thread, Compose, Snooze, Snoozed, Mailboxes, Inbox zero, Search)
- `Nimbra/Engine/`: the engine's host (its threads, folders, Keychain, DNS resolver, OAuth config and errors)
- `Nimbra/Model/`: the app state (`AppModel` and its areas), threads, messages, people, accounts, and the sample mail with its engine
- `Config/`: the build's xcconfig, and the OAuth client ids (`OAuth.xcconfig`, gitignored)
- `docs/architecture.md`: the layers, and where a feature plugs in
- `Nimbra/Design/`: text styles, icons, avatars, label pills, grouped cards and buttons
- `Nimbra/Resources/`: the asset catalog (colors, icons), fonts, the app icon (`AppIcon.icon`, the same Icon Composer file as the Mac app) and the string catalog
- `NimbraTests/`: unit tests

## Contributing

Bug fixes are welcome; for anything bigger, start a discussion first. [CONTRIBUTING.md](CONTRIBUTING.md) has how to
run it, what a good change looks like, and the commit style ([Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/)).
[CLAUDE.md](CLAUDE.md) holds the rules this codebase follows.
Found a security problem? Report it privately: see [SECURITY.md](SECURITY.md).

## License

[MIT](LICENSE)
