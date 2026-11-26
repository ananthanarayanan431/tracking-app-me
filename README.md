# Spent

A private screen-time tracker for macOS, built with SwiftUI. Spent records which app
(and which browser tab) is in front, then shows where your time goes: overview, insights,
a focus timer, habits, campaigns, daily limits and alerts. Everything stays in `~/.spent`
on this Mac.

## Features

- **Overview**: day / week / month / year, Mac and iPhone, a timeline of your day, hourly and daily
  charts, top apps, websites, categories and browser profiles, statistics and a full session log.
- **Insights**: averages, trend chart, weekday × hour heatmap, biggest changes, AI coach.
- **Focus**: focus timer (⌥⇧F global shortcut), distraction nudges, daily goals and a streak.
- **Habits** and **Campaigns**: tick-box or amount habits with reminders; N-day campaigns with dots.
- **Limits**: daily limits per app, site or category with alerts at 80%, at the limit and beyond.
- **Away from the screen**: after a long break, log what you were doing (can tick a habit).
- **Menu bar**: today's total, focus control, habits, campaigns, pause.
- **Settings**: 7 colour themes plus a custom accent, labels (productive / neutral / distracting),
  iPhone import via Shortcuts, privacy switches, CSV export, launch at login.

## Build and install

Requires macOS 14+ and the Swift toolchain (Xcode or Command Line Tools).

```bash
scripts/build-app.sh            # builds build/Spent.app
scripts/build-app.sh --install  # also copies it to ~/Applications and opens it
```

For quick iteration: `swift run`. Tests: `scripts/test.sh`.

Closing the window keeps Spent recording from the menu bar; quit it from the menu bar item.
Turn on **Settings › Mac tracker › Start Spent at login** so tracking never stops.

## AI summaries

Paste an Anthropic API key in **Settings › Privacy** (stored in the macOS Keychain). Only the
aggregated totals on screen are sent, and only when you press the button.

## Permissions

- **Automation**: the first time a browser is in front, macOS asks whether Spent may
  control it. Allow it to record site and page titles; otherwise only the browser name is kept.
- **Notifications**: used for limits, habit reminders and focus sessions.
