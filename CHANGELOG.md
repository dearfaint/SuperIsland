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
- Initialized the durable project documentation scaffold.
