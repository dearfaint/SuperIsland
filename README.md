<p align="center">
  <img src="assets/logo.png" width="96" height="96" alt="SuperIsland" />
</p>

<h1 align="center">SuperIsland</h1>

<p align="center">
  <strong>English</strong> · <a href="README.zh-CN.md">简体中文说明</a>
</p>

<p align="center">
  Transform your Mac's notch into a live, interactive island.<br />
  Now Playing · Battery · Weather · Calendar · Notifications · HK/A Stocks · Computer Status · Extensions
</p>

<p align="center">
  <a href="https://dynamicisland.app">Website</a> ·
  <a href="https://dynamicisland.app/docs">Docs</a> ·
  <a href="https://github.com/dearfaint/SuperIsland/releases">Releases</a>
</p>

---

## Requirements

- macOS 14 Sonoma or later
- Xcode 15+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — `brew install xcodegen`
- Node.js 18+ and pnpm (only needed to work on extensions)

---

## Current feature set

This repository includes the original SuperIsland modules plus the following additions and fixes:

- English and Simplified Chinese native UI, including localized permissions, dates, times, numbers, and measurements.
- A bundled **HK + A Stocks** extension using TradingView scanner endpoints with Yahoo Finance fallback. It accepts HKEX, SSE, and SZSE symbol formats without calling mainland quote providers. Hong Kong quotes may be delayed by about 15 minutes.
- A bundled **Computer Status** extension with aggregate CPU, Activity Monitor-style memory, disk, Apple Silicon SoC temperature, fan RPM, power, uptime, and thermal status.
- Restored compact module cycling and stable compact layouts for stocks and computer status.
- A single extension activation source of truth in **Settings -> Extensions**, so stopped extensions no longer remain enabled in the menu-bar Modules submenu.
- An arm64 local DMG build path with matching app and Node architectures plus certificate-free ad-hoc signing for local testing.

For installation, usage, data-source details, and troubleshooting, read the [Simplified Chinese guide](README.zh-CN.md).

---

## Setup

```bash
git clone https://github.com/dearfaint/SuperIsland.git
cd SuperIsland
xcodegen generate
open SuperIsland.xcodeproj
```

Select the `SuperIsland` scheme, choose your Mac as the destination, and hit Run.

> On first launch the app will ask for Accessibility, Calendar, and Location permissions. These are required for the relevant modules to work.

## Localization

The native app supports English and Simplified Chinese (`zh-Hans`) and follows the macOS app language setting. English is the fallback language. JavaScript extensions can provide localized manifest metadata, settings fields, and runtime view text through locale maps.

---

## Building a DMG

For a quick local test build:

```bash
./scripts/build-dmg.sh
```

The local arm64 DMG is ad-hoc signed when no Apple development certificate is installed. It is suitable for local testing but is not a notarized public distribution build.

For a signed release, use a Developer ID certificate and notarization credentials. Copy `.env.template` to `.env` and fill in:

```
APPLE_ID=you@example.com
APP_SPECIFIC_PASSWORD=xxxx-xxxx-xxxx-xxxx
TEAM_ID=XXXXXXXXXX
SIGNING_IDENTITY=Developer ID Application: Your Name (TEAMID)
```

Then run:

```bash
./scripts/build-and-release.sh
```

This archives a universal app, bundles a universal runtime, notarizes the DMG, and produces `build/SuperIsland.dmg`.

Release and packaging notes are in [docs/RELEASE.md](docs/RELEASE.md).

---

## Project structure

```
SuperIsland/
  App/              AppDelegate, AppState
  Modules/          Built-in modules (Battery, NowPlaying, Weather, …)
  Settings/         Settings window views
  Utilities/        UpdateChecker, AutoUpdater, helpers
  Views/            CompactView, ExpandedView, IslandWindow
ExtensionHost/      JS runtime, extension manager, bridge
Extensions/         Bundled extensions (pomodoro, whatsapp-web, …)
scripts/            Build & release scripts
```

---

## Extensions

Extensions are JavaScript packages that run inside a sandboxed JavaScriptCore context. Read the full guide at [dynamicisland.app/docs](https://dynamicisland.app/docs) or in [EXTENSIONS.md](EXTENSIONS.md).

## Notifications

The Notifications module supports source-level controls for SuperIsland extensions, the bundled WhatsApp integration, and compatible public app broadcasts. See [docs/NOTIFICATIONS.md](docs/NOTIFICATIONS.md).
## Now Playing

Now Playing supports system media, Apple Music, Spotify, and opt-in browser media detection for supported Chromium browsers. See [docs/NOW_PLAYING.md](docs/NOW_PLAYING.md).

## Energy settings

Settings -> General -> Power includes Normal, Smart, and Low Power modes. Smart reduces background refresh while the island is collapsed, while Low Power slows non-essential work and pauses inactive extension timers. See [docs/ENERGY.md](docs/ENERGY.md) for profiling notes and scheduler behavior.

## Appearance

Home slots, compact island size, animation intensity, and reduced motion can be configured in Settings. See [docs/APPEARANCE.md](docs/APPEARANCE.md).

## Calendar

The Calendar module supports account/source selection, holiday and birthday filters, duplicate collapse, and meeting-link actions. See [docs/CALENDAR.md](docs/CALENDAR.md).

## File Shelf

The built-in Shelf module can stage local files, folders, URLs, text snippets, and images from the island. See [docs/SHELF.md](docs/SHELF.md).

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

---

## Updates

SuperIsland checks for updates automatically on launch. When a new version is available a dialog appears — click **Update** to download and install without reinstalling.

---

## Star History

<a href="https://www.star-history.com/#shobhit99/superisland&Date">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=shobhit99/superisland&type=Date&theme=dark" />
    <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/svg?repos=shobhit99/superisland&type=Date" />
    <img alt="Star History Chart" src="https://api.star-history.com/svg?repos=shobhit99/superisland&type=Date" />
  </picture>
</a>
