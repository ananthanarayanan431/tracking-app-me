# Spent

A private screen-time tracker for macOS, built with SwiftUI. Spent records which app
(and which browser tab) is in front, then shows where your time goes: overview, insights,
a focus timer, habits, campaigns, daily limits and alerts. Everything stays in `~/.spent`
on this Mac.

## Build and install

Requires macOS 14+ and the Swift toolchain (Xcode or Command Line Tools).

```bash
scripts/build-app.sh            # builds build/Spent.app
scripts/build-app.sh --install  # also copies it to ~/Applications and opens it
```

For quick iteration: `swift run`.

## Permissions

- **Automation**: the first time a browser is in front, macOS asks whether Spent may
  control it. Allow it to record site and page titles; otherwise only the browser name is kept.
- **Notifications**: used for limits, habit reminders and focus sessions.
