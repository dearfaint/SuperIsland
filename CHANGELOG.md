# Changelog

This project follows a concise, date-based change log.

## Unreleased

- Added English and Simplified Chinese localization infrastructure for the native app and system permission descriptions.
- Localized native app navigation, settings, onboarding, status, weather, calendar, and battery text.
- Switched user-facing dates, times, durations, temperatures, and wind speeds to locale-aware platform formatters.
- Added the missing bundled `live-football` extension to the generated app resources.
- Migrated the WhatsApp provider lockfile and extension build command to pnpm.
- Added focused regression tests for native localization catalogs, permission strings, and representative printf formats.
- Added a backward-compatible localization contract for extension manifest metadata, settings fields, and runtime view text maps.
- Prevented automatic Now Playing track changes from stealing focus from an active extension such as a running Pomodoro timer.
- Added a bundled Computer Status extension with read-only whole-machine CPU, Activity Monitor-style memory, disk, SoC temperature, fan RPM, power, and thermal metrics.
- Added a bundled HK + A Stocks extension using non-mainland quote endpoints for Hong Kong and A-share watchlists.
- Fixed extension discovery so default-enabled bundled extensions no longer disappear from compact cycling after an update.
- Restored compact module swiping, kept selected stock and computer-status extensions visible, and removed duplicate extension toggles from the menu-bar Modules submenu.
- Updated the stock minimal compact layout with market-prefixed codes, single-line prices, red-up/green-down quote colors, and the original compact width.
- Prevented compact-state collapse animation from overshooting the physical notch, stabilized Computer Status values and island shadows during refresh, and replaced its tall rows with fixed circular metrics including fan RPM.
- Cleared the Xcode concurrency, CoreAudio pointer, and generated-project upgrade warnings shown by Xcode 26.
- Fixed local Apple Silicon DMG packaging so certificate-free builds continue, re-sign the bundled Node runtime, and produce a consistent arm64 application.
- Expanded the repository homepage with the current custom feature set and added a complete Simplified Chinese installation and usage guide.
- Initialized the durable project documentation scaffold.
