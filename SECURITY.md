# Security policy

Nimbra holds your mail, your sign-ins and your passwords, so we take security reports seriously. Thanks for helping
keep it safe.

## Supported versions

| Version | Fixes |
| --- | --- |
| The latest release | ✅ |
| `main` | ✅ |
| Anything older | ❌ Update first |

If you're on an older version, update and check the problem is still there before you report it.

## Reporting a vulnerability

**Please don't open a public issue, discussion or pull request for a security problem.**

Report it privately through GitHub: [Report a vulnerability](https://github.com/luangjokaj/nimbra-ios/security/advisories/new)
(the repository's **Security** tab › **Report a vulnerability**). The report stays private between you, the
maintainers and anyone we invite to help fix it.

Please include:

- what an attacker can do, and what they need first (an email they send you, a network they control, the unlocked
  iPhone…);
- the steps to reproduce it, and a proof of concept if you have one (a crafted `.eml` is ideal);
- the Nimbra version and your iOS version;
- anything you've already found about the cause.

## What to expect

Nimbra is a small project, so these are aims rather than promises:

- We confirm we've received your report within a week.
- We tell you whether we can reproduce it and how serious we think it is, and keep you posted while we fix it.
- We aim to ship a fix for a confirmed serious problem within 30 days, usually much sooner.
- When the fix is out, we publish a GitHub Security Advisory and credit you by name, unless you'd rather we didn't.

Please give us a reasonable chance to ship a fix before you publish anything, and tell us when you plan to.

## Scope

In scope:

- **Untrusted email.** Anything a received message can do: running script, loading remote content when it
  shouldn't, opening links or apps by itself, reading local files.
- **Secrets.** Sign-ins, refresh tokens and passwords leaving the Keychain, or being logged or written to disk.
- **The local store.** Reading stored mail without the Keychain key, or anything written to disk in the clear
  (including `UserDefaults` and caches).
- **Sign-in.** The Google and Microsoft OAuth flows, their redirects back to the app, and taking over another
  account.
- **Transport.** IMAP and SMTP connections without certificate checks, or downgraded to plain text.
- **Sending.** Mail sent without the user pressing Send, to the wrong recipients, or from the wrong account.

Elsewhere:

- A bug in iOS, WebKit or another dependency belongs to that project; report it there. If Nimbra hasn't picked up a
  published fix yet, that's ours, so tell us.
- Not counted: attacks that need someone who already controls your unlocked iPhone or your account, social
  engineering, and missing hardening with no real way to attack it.

## Safe harbor

We won't take legal action against you, or ask anyone else to, for security research done in good faith under this
policy. Good faith means you test only against your own accounts, devices and data, don't keep or share data that
isn't yours, and give us a reasonable chance to fix the problem before you publish anything.

If you're not sure whether something is allowed, ask us in your report first.
