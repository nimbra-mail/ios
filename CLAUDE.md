# CLAUDE.md

Guidance for working in this repository. The project-wide notes (the Figma file, the other
repos, shared rules) are in `../CLAUDE.md`.

## What this is

`nimbra-ios` is the **Nimbra iOS app**: a SwiftUI mail client, the iPhone companion to the
macOS app in `../nimbra-app`. Designs: the Figma file's **📱 iOS** page,
https://www.figma.com/design/s6tsR2l2X4MKmoA1dNlm4I/Nimbra?node-id=7409-376.

## Commands

```bash
xcodegen                    # regenerate Nimbra.xcodeproj after adding or moving files
open Nimbra.xcodeproj
xcodebuild -project Nimbra.xcodeproj -scheme Nimbra \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

Building needs a Mac with Xcode 26 or newer. Never claim a change builds without an Xcode
build. Launch argument `-SignedIn YES` opens past Welcome on the sample mail.

## Git commits

Follow [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/). No AI
mentions and no co-author lines. When asked to commit and push, use the `mr-deployer`
agent.

## Stack

iOS 26+, Swift 6 language mode, SwiftUI only, Observation (`@Observable`). Default actor
isolation is `MainActor` (`project.yml`): plain data types are declared `nonisolated` so
their conformances work anywhere. XcodeGen generates the project; `Nimbra.xcodeproj` is not
committed. No third-party packages without asking first.

## Rules that matter here

**Screens match Figma one to one.** Build from the frame (its Dark and Light twins):
sizes, spacing, radii, icons and copy come from there. Where the design draws the system
look (the top bar's buttons, sheets), use the system view; where it deviates (the tab bar
and Compose button, the Thread action bar, the formatting bar, the chips, the rows), build
it from `Nimbra/Design/`, never from raw values in a screen.

**Never hardcode a design value.** Colors are the asset-catalog color sets named after the
Figma variables (`bg/list` is `BgList`, used as `Color.bgList`; `accent/violet` is
`AccentColor`). Add a color as a color set with its Light and Dark values from the
`Nimbra` collection, never `Color(red:green:blue:)` in a view (the brand gradient and the
avatar tones, which are not variables, live in `Design/BrandGradient.swift` and
`Model/Tone.swift`). Text uses `.nimbraText(_:)` with a `NimbraTextStyle`, the Figma
`iOS/*` styles: Geist, Geist Mono and Instrument Serif, scaling with Dynamic Type.

**Liquid Glass is the system's.** Floating bars and round buttons use `.glassEffect`
(inside a `GlassEffectContainer` when they sit together). Unselected items on glass use
the primary text color and the selected one the accent, as Apple's guidelines say.

**Icons are the Figma kit's Lucide glyphs**, template vectors in `Assets.xcassets/Icons`,
drawn with `Icon(.name, size:)` and colored by the foreground style. Never substitute an
SF Symbol for a glyph the design shows.

**Every user-visible string is localizable.** Literals in `Text`, `Button`, `Label` and
friends go to `Localizable.xcstrings`; other strings use `String(localized:)` or
`LocalizedStringResource`. Mail content (names, subjects, bodies) is never a localization
key: use `Text(verbatim:)`. No em dashes in copy.

**Accessibility.** Every icon-only control has a label; rows combine into one element;
selected state is a trait, not just a color.

**Private by default.** Mail and sign-ins stay on the device (Keychain, an encrypted
store), never in `UserDefaults` or logs.

## Layout

| Path                 | What lives there                                             |
| -------------------- | ------------------------------------------------------------ |
| `project.yml`        | XcodeGen spec: target, iOS 26, Swift 6, build settings      |
| `Nimbra/App/`        | App entry, root (Welcome or tabs), the tab bar              |
| `Nimbra/Features/`   | One folder per screen                                        |
| `Nimbra/Model/`      | App state (`AppModel`), mail types, sample data             |
| `Nimbra/Design/`     | Text styles, icons, avatars, pills, cards, buttons          |
| `Nimbra/Resources/`  | Asset catalog (colors, icons), fonts, app icon, strings     |
| `NimbraTests/`       | Swift Testing tests for the model                           |
