# Changelog

This project follows a concise, date-based change log.

## Unreleased

- Bumped the app release version to 1.1.0 with build 12 and pointed the in-app GitHub update check at `dearfaint/SuperIsland`.
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
- Fixed Shelf drops for text, source-code, JSON, and other content-typed files that Finder does not advertise as file URLs.
- Added local third-party extension installation with staged permission review, safe manifest validation, immediate activation, and uninstall cleanup for extension files, settings, and stored data.
- Enforced declared storage and notification permissions and restricted bundled WhatsApp bridge controls to the WhatsApp extension.
- Added the installable Nudge extension for local one-time reminders with preset delays, persistent absolute due times, completion, ten-minute snooze, and due notifications.
- Added 1–1440 minute custom delays and selectable system, silent, or named custom alert sounds to Nudge.
- Fixed Nudge's minimal countdown width, replaced the oversized custom-minute field with a compact Apply control, and made named or custom sound previews play on explicit user action.
- Corrected the Simplified Chinese name of Agents Status from the literal “代理状态” to “Agents 状态”.
- Preserved Chinese and other input-method composition text across live extension refreshes, and deferred Return submission until composition completes.
- Updated extension installation review to lead with the extension icon, name, version, author, and purpose before requested permissions.
- Added a Weather data-source setting with Automatic, QWeather, Open-Meteo, and Caiyun Weather options; QWeather now generates JWT tokens locally from the credential ID, project ID, and Ed25519 private key, uses the current air-quality and weather-alert endpoints, shows China AQI categories and high-temperature alerts, and includes a visible active-source label. Caiyun Weather now supports signed App Key/App Secret requests while retaining legacy token fallback.
- Refined the Weather expanded and Home layouts so active warnings sit beside AQI as compact icons with hover popovers, Home weather warnings stay close to the live temperature, raw warning colors such as `yellow` are localized, and the UV detail is labeled as the daily peak value.
- Initialized the durable project documentation scaffold.
