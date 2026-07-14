# SuperIsland Architecture

## Current structure

- `SuperIsland/App` owns application lifecycle and the shared `AppState` preferences/state model.
- `SuperIsland/Views` and `SuperIsland/Window` render and position the compact, expanded, and full-expanded island surfaces.
- `SuperIsland/Modules` contains the built-in Battery, Calendar, Connectivity, Notifications, Now Playing, Shelf, System HUD, Teleprompter, and Weather features.
- `SuperIsland/Settings`, `SuperIsland/Onboarding`, and `SuperIsland/Utilities` provide user configuration, first-run permissions, updates, analytics, and shared platform services.
- `ExtensionHost` discovers manifests, runs JavaScript in JavaScriptCore, renders extension view nodes, stores settings, and exposes permission-gated host APIs.
- `Extensions` contains the bundled JavaScript extensions and their optional provider processes.
- `project.yml` is the source of truth for the generated Xcode project and bundled-extension copy phase.

The application is primarily coordinated through `AppState` and feature-specific singleton managers. JavaScript extensions do not render SwiftUI directly; they return `ViewNode` values that `ExtensionRendererView` translates into native views.

## External integrations

- Aptabase receives application analytics.
- GitHub Releases supplies update metadata and DMG downloads.
- Open-Meteo supplies weather and air-quality data.
- Linear, Last.fm, WhatsApp Web, ESPN, Anthropic, and ChatGPT APIs are used by optional extensions or providers.
- The Now Playing module uses AppleScript and the private macOS MediaRemote framework, which prevents a conventional Mac App Store distribution path.

## Technical decisions

- XcodeGen remains the project generator; generated Xcode project files are not maintained manually.
- English remains the source and fallback language. Native UI strings use `SuperIsland/Resources/Localizable.xcstrings`; permission descriptions use `SuperIsland/Resources/InfoPlist.xcstrings`; both provide `zh-Hans` translations.
- Native application localization and JavaScript extension localization are separate layers because extension content is generated at runtime outside SwiftUI's localization lookup.
- JavaScript extension user-facing strings may remain plain English strings or use locale maps such as `{ "en": "Settings", "zh-Hans": "设置" }`; the host resolves the best current locale and falls back to English.
- Distribution identity and external service ownership remain unchanged until the replacement bundle ID, update repository, analytics policy, and OAuth endpoints are explicitly confirmed.
