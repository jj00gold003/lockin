# 🔒 LockIn

**Kill multitask. Ship deep work.**

LockIn is a free, open-source macOS app for knowledge workers and developers:
focus sessions with real distraction blocking — distract-proof Pomodoro, tasks,
habits, and stats. All local. Zero telemetry. Forever.

![LockIn demo](docs/assets/demo.gif)

<!-- demo.gif placeholder: record a 15s screen capture "start focus → open a
blocklisted app → cover overlay appears", convert to GIF, drop it at
docs/assets/demo.gif -->

## ✨ Features

- 🎯 **Focus & Pomodoro** — 25/5 cycles with long breaks, or unbounded free focus
- 🛡️ **Deep Work Shield** — block distracting apps during sessions (cover overlay or hard minimize)
- ✅ **Tasks** — link focus time to tasks automatically
- 🔥 **Habits** — streaks + GitHub-style heatmap
- 📊 **Stats** — daily/weekly focus time, completion rate, distraction curve
- 🌐 **English & 简体中文** · 📴 Works fully offline · 🚫 No telemetry

## 📦 Install

**Homebrew** (after the cask is accepted into homebrew-cask — coming soon, see [`Casks/lockin.rb`](Casks/lockin.rb) for the pending template):

```bash
brew install --cask lockin
```

**Manual:** download `LockIn-x.y.z.dmg` from the [Releases](https://github.com/andy0332hk/lockin/releases) page, open it, and drag LockIn to Applications.

> Note: until the first notarized release is published, building from source is the recommended way to try LockIn.

## 🔐 Permissions

| Permission | Why | Required? |
|---|---|---|
| None | App monitoring & cover blocking work out of the box | — |
| Accessibility | Hard block: minimize distracting apps | Optional |

Everything runs on your Mac. No network calls, no analytics, no accounts.

## 🛠️ Build from source

```bash
brew install xcodegen
xcodegen generate
open LockIn.xcodeproj   # Cmd+R
```

Requires macOS 14+ and Xcode.

## 🚀 Releasing (maintainers)

`scripts/release.sh` builds a Release dmg, signs it with a Developer ID
certificate, submits it for Apple notarization, and staples the ticket.
It requires two environment variables and fails fast without them:

```bash
APPLE_IDENTITY="Developer ID Application: Your Name" \
NOTARY_PROFILE="lockin-notary" \
bash scripts/release.sh
```

## 📄 License

MIT
