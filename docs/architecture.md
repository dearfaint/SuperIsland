# SuperIsland Architecture

## Current structure

- `SuperIsland/App` owns application lifecycle and the shared `AppState` preferences/state model.
- `SuperIsland/Views` and `SuperIsland/Window` render and position the compact, expanded, and full-expanded island surfaces.
- `SuperIsland/Modules` contains the built-in Battery, Calendar, Connectivity, Notifications, Now Playing, Shelf, System HUD, Teleprompter, and Weather features.
- `SuperIsland/Settings`, `SuperIsland/Onboarding`, and `SuperIsland/Utilities` provide user configuration, first-run permissions, updates, analytics, and shared platform services.
- `ExtensionHost` discovers manifests, runs JavaScript in JavaScriptCore, renders extension view nodes, stores settings, and exposes permission-gated host APIs.
- `Extensions` contains the bundled JavaScript extensions and their optional provider processes.
- `InstallableExtensions` contains standalone third-party extension folders used to exercise the reviewed install and uninstall path without entering bundled discovery.
- `project.yml` is the source of truth for the generated Xcode project and bundled-extension copy phase.

The application is primarily coordinated through `AppState` and feature-specific singleton managers. JavaScript extensions do not render SwiftUI directly; they return `ViewNode` values that `ExtensionRendererView` translates into native views.

## External integrations

- Aptabase receives application analytics.
- GitHub Releases for `dearfaint/SuperIsland` supplies update metadata and DMG downloads.
- The built-in Weather module can resolve data by region and user preference: Automatic uses QWeather for mainland China when QWeather credentials are configured, otherwise Open-Meteo; explicit QWeather or Caiyun Weather selections fall back to Open-Meteo when their credentials are unavailable. QWeather generates JWT Bearer tokens locally from the credential ID, project ID, and Ed25519 private key, uses current air-quality and weather-alert endpoints, and includes current conditions, hourly forecast, daily high/low, China AQI category, and active warnings. Caiyun Weather prefers signed App Key/App Secret requests and keeps legacy token requests as a fallback.
- Linear, Last.fm, WhatsApp Web, ESPN, Anthropic, ChatGPT, TradingView, and Yahoo Finance APIs are used by optional extensions or providers.
- The Now Playing module uses AppleScript and the private macOS MediaRemote framework, which prevents a conventional Mac App Store distribution path.
- The bundled Computer Status extension uses the host's `system` permission and a native read-only provider for aggregate whole-machine CPU, Activity Monitor-style memory, disk, fan, power, and thermal metrics. On Apple Silicon it reads de-duplicated PMU die sensors through in-process IOKit HID access and reports the hottest valid SoC value; other systems fall back to `ProcessInfo.thermalState`. Fan status reads count and RPM values through AppleSMC without exposing or performing SMC writes.

## Technical decisions

- XcodeGen remains the project generator; generated Xcode project files are not maintained manually.
- English remains the source and fallback language. Native UI strings use `SuperIsland/Resources/Localizable.xcstrings`; permission descriptions use `SuperIsland/Resources/InfoPlist.xcstrings`; both provide `zh-Hans` translations.
- Native application localization and JavaScript extension localization are separate layers because extension content is generated at runtime outside SwiftUI's localization lookup.
- JavaScript extension user-facing strings may remain plain English strings or use locale maps such as `{ "en": "Settings", "zh-Hans": "设置" }`; the host resolves the best current locale and falls back to English.
- User-installed extensions are copied into a private temporary snapshot before permission review, then copied into Application Support after confirmation. They must use a non-reserved safe ID, may request only known host permissions, and cannot replace bundled or existing extensions. Installation activates the extension after confirmation; uninstall is restricted to the discovered user-install directory and removes namespaced settings and storage.
- Installable sample packages stay outside `Extensions` and the `project.yml` copy list. Nudge therefore exercises the same folder installation path as an independently distributed extension instead of appearing as a bundled module.
- Extension permissions are runtime boundaries, not metadata alone: network, storage, notifications, media, system health, and AI usage access are gated by the manifest. Feature-specific WhatsApp bridge methods remain restricted to the bundled WhatsApp extension, and notification tap actions can target only the extension that created them.
- Notification-enabled extensions may play a named macOS sound through the host. The bridge accepts a sound name only, rejects path separators, and respects both SuperIsland's extension-notification enablement and the cached macOS notification-sound setting, which refreshes when the app becomes active; custom user sounds remain in the standard macOS sound library rather than exposing arbitrary file access to JavaScript.
- Named sound previews use a separate notification bridge method that is accepted only while the host is handling an explicit extension action. This lets Settings preview a sound without depending on notification authorization while preventing render and timer callbacks from producing unsolicited preview audio.
- Extension input boxes retain their existing defaults, with optional compact density and a localized submit label for narrow numeric or command inputs that need an explicit apply action.
- The bundled HK + A Stocks extension intentionally uses non-mainland quote endpoints. TradingView scanner is the primary source for HKEX, SSE, and SZSE symbols; Yahoo Finance quote data is a fallback for `.HK`, `.SS`, and `.SZ` tickers. It does not call Sina, Eastmoney, Tencent Finance, Xueqiu, or other mainland quote endpoints.
- Distribution identity and external service ownership remain unchanged until the replacement bundle ID, analytics policy, and OAuth endpoints are explicitly confirmed. The update repository is `dearfaint/SuperIsland`.
