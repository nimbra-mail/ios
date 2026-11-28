# Contributing to Nimbra for iOS

Nimbra for iOS is the iPhone companion to [Nimbra for Mac](https://github.com/nimbra-mail/desktop), written in SwiftUI.
It's small on purpose: fast, private, and nothing in it you didn't ask for. Thanks for wanting to help. This page is
the rules, and the things review keeps asking for, written down so you don't have to learn them there.

## What we take

Bug fixes are always welcome. For anything else (a new feature, a setting, a gesture, a restyle, a new provider),
open a [discussion](https://github.com/nimbra-mail/ios/discussions) first and wait for a yes. Reviewing a pull
request takes longer than writing one, and a feature that doesn't fit gets declined however good the code is.

A crash, a regression, and something that shipped and behaves wrong are bugs. A new setting, a new gesture and a
restyle are features, even when the pull request calls them a fix.

The best help often isn't a pull request:

- **Duplicates.** Comment on the issue with a link to the original.
- **Fixed bugs.** If an open issue no longer happens on `main`, say so and give the commit.
- **A pull request that already covers your bug.** Test it and comment with what you saw. That beats a second one.

### Out of scope

- **Accounts, servers or sync of our own.** Nimbra talks straight to your mail provider. Nothing goes through a
  server of ours.
- **AI features in the base app.** Not now; open a discussion if you want to argue for one.
- **Bloat.** Anything that makes the app slower to open or heavier to use needs a very good reason.
- **Third-party packages** without a discussion first.

## Getting it running

You need a Mac with Xcode 26 or newer and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
brew install xcodegen
xcodegen                        # Nimbra.xcodeproj, from project.yml
open Nimbra.xcodeproj
```

Run the `Nimbra` scheme on an iOS 26 simulator. The app runs on built-in sample mail; add the launch argument
`-SignedIn YES` to start on the inbox. Run `xcodegen` again after adding, moving or removing files: the project is
generated and never committed. Never commit a client id, a secret or a token.

Where things live is in [Layout](docs/development.md#layout).

## What a good change looks like

### It matches the design

Every screen is drawn in [Figma](https://www.figma.com/design/s6tsR2l2X4MKmoA1dNlm4I/Nimbra?node-id=7409-376) first,
and the app matches it one to one. A UI change looks like it was always there. Use the color sets, the
`.nimbraText(_:)` styles and the building blocks in `Nimbra/Design/` rather than new values, and match the spacing of
the screens next to it. "Looks close" isn't a match: compare screenshots at the same size, in light and dark.

Things review checks on every UI change:

- **Both themes.** Light and dark.
- **Dynamic Type.** Text follows the size set on the iPhone; check the largest sizes too.
- **Liquid Glass is the system's.** Floating bars and round buttons use `.glassEffect`; nothing fakes it.
- **Kit icons.** The Figma kit's Lucide glyphs through `Icon(.name)`, never an SF Symbol in their place.
- **Accessibility.** Every icon-only control has a label, and selection is a trait as well as a color.
- **Nothing snaps.** State changes animate, and respect Reduce Motion. A change in motion comes with a screen
  recording.

### It's simple

A bug that happens sometimes usually means two pieces of code disagree about who owns the state. Prefer the change
that removes code. A large change to save a little isn't worth it.

### It's fast

Don't add work to launch or to the main thread, and keep views cheap to redraw. Anything cached has to stay correct.

### It's private and safe

- Secrets (sign-ins, tokens, passwords) live in the Keychain only. Mail on disk goes through an encrypted store,
  never `UserDefaults` or a plain file.
- Email HTML is untrusted: never run its scripts or load remote content it asks for by itself.
- TLS certificates are always checked.
- No new network calls beyond the user's own mail servers without a discussion first.

Found a security problem? Don't open an issue: see [SECURITY.md](SECURITY.md).

## Code style

- Swift 6, SwiftUI and Observation (`@Observable`). Default actor isolation is `MainActor`; plain data types are
  `nonisolated`.
- The build adds no new warnings.
- One type per file, in the feature folder it belongs to. Read the surrounding code first and match its naming and
  idioms.
- Every user-visible string is localizable; mail content uses `Text(verbatim:)`. No em dashes in copy.
- Doc comments say what a thing is for, in plain sentences, and the why goes in the commit message. Don't comment
  what the code already says.

[CLAUDE.md](CLAUDE.md) has the full list of rules.

## Testing

Reproduce the bug before you fix it, ideally with a test that fails. Then fix it and watch the same test pass.
Tests run the real code; a copy of the logic inside a test proves nothing about the app.

```sh
xcodebuild -project Nimbra.xcodeproj -scheme Nimbra \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

Never use a real mailbox in a test. Build fixtures with `example.com` addresses. Screenshots for issues, pull requests
and the README use the sample mail, never someone's real mail.

## Commit messages

Every commit follows [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/):

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

- **Types:** `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`.
- **Description:** lowercase, imperative mood, no period at the end. Say what changes for the user:
  `fix: keep the tab bar above the keyboard`, not `fix: update TabBar.swift`.
- **Scope** when it makes the area clearer: `feat(snooze): pick any time in the calendar`,
  `fix(thread): fold earlier messages after a reply`.
- **Body** for anything bigger than a one-liner: what changed and why, in plain sentences, after a blank line. When
  a change has several parts, describe each one.
- **Breaking changes** get a `!` after the type or scope and a `BREAKING CHANGE:` footer saying what breaks and what
  to do about it.

Pull requests are squashed when merged, so the pull request title becomes the commit subject on `main`. Write it as a
Conventional Commit too. CI checks it.

## Reporting a bug

Use the bug report form; blank issues are off, and feature ideas go to
[Discussions](https://github.com/nimbra-mail/ios/discussions). The fastest bug to fix is one with a screen
recording. Include:

- the commit or version,
- your iPhone and iOS version (or the simulator),
- the account type (Gmail, IMAP with the provider, Microsoft, or sample data),
- the steps, and how often it happens if it's only sometimes,
- the crash report, if it crashed.

Leave out real addresses, subjects and message text. Redact screenshots.

## Pull requests

- **Issue first.** Every pull request closes an issue: open one (or find it) before you start, and put
  `Closes #<issue>` in the description. Comment on the issue that you're taking it, so two people don't fix the same
  bug.
- **One problem per pull request,** with everything that fix needs: code, tests, docs. Cleanup, refactors and a
  second fix go in their own pull requests.
- **Show that it works.** Under Verification, say how you reproduced the bug and what you saw after the fix, with
  screenshots in light and dark, or a video for anything about motion or timing. "Tests pass" is not evidence.
- **Keep it green and mergeable.** CI (build, tests, the title check) passes, and the branch rebases cleanly on
  `main`.
- **Update the docs** a user would read: the README when what the app does changes, and [docs/development.md](docs/development.md) when how it is built changes.
- We don't owe a review or a merge, and a good pull request can still wait. Sometimes your work lands in a different
  shape; you stay on it as a `Co-authored-by:` trailer.

Releases, version bumps and anything posted publicly are the maintainer's job. Don't bump the version in a pull
request.

## Working with a coding agent

Using one is fine. Point it at this file, the README and [docs/architecture.md](docs/architecture.md) first. Check its diff yourself before
you open the pull request: you're the one answering for it. For risky logic (sync, sending, encryption, sign-in),
get a second review before and after, and reproduce each finding before acting on it. Never let an agent near a real
mailbox or your Keychain while it tests.

## License

Nimbra is [MIT licensed](LICENSE). By sending a pull request you agree that your contribution is licensed under the
same terms, with no further conditions.
