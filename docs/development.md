# Developing Nimbra for iOS

How to build and run the app, sign in with Google and Microsoft in your own build, work on the engine beside it, and where the code lives. [Architecture](architecture.md) explains the layers, and [CONTRIBUTING.md](../CONTRIBUTING.md) what a good change looks like.

- [Getting started](#getting-started)
- [Sign-in](#sign-in)
- [Working on the engine](#working-on-the-engine)
- [Tests](#tests)
- [Layout](#layout)

## Getting started

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

## Tests

```sh
xcodebuild -project Nimbra.xcodeproj -scheme Nimbra \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

The tests (Swift Testing) are in `NimbraTests`: the app model on a fake engine (listing, paging, actions, offline and signed-out states, sign-in), IMAP setup, error mapping, the OAuth config, the Keychain store (in the simulator), MX records, and the engine's offline calls.

## Layout

- `project.yml`: the XcodeGen spec (target, iOS 26, Swift 6, build settings)
- `Nimbra/App/`: the app entry, the root view (Welcome or the tabs) and the tab bar
- `Nimbra/Features/`: one folder per screen (Welcome, Add account and IMAP setup, Inbox, Thread, Compose, Snooze, Snoozed, Mailboxes, Inbox zero, Search)
- `Nimbra/Engine/`: the engine's host (its threads, folders, Keychain, DNS resolver, OAuth config and errors)
- `Nimbra/Model/`: the app state (`AppModel` and its areas), threads, messages, people, accounts, and the sample mail with its engine
- `Config/`: the build's xcconfig, and the OAuth client ids (`OAuth.xcconfig`, gitignored)
- `docs/architecture.md`: the layers, and where a feature plugs in (see [Architecture](architecture.md))
- `Nimbra/Design/`: text styles, icons, avatars, label pills, grouped cards and buttons
- `Nimbra/Resources/`: the asset catalog (colors, icons), fonts, the app icon (`AppIcon.icon`, the same Icon Composer file as the Mac app) and the string catalog
- `NimbraTests/`: unit tests
