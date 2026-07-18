# SuperIsland Resolved Issues

Record resolved issues with date, symptom, cause, fix, and verification evidence.

## 2026-07-16 - Built-in weather has only one global source

- Symptom: the Weather module always used Open-Meteo, which is practical globally but does not match mainland China services for China AQI or local warnings such as high-temperature alerts.
- Cause: weather fetching had no source preference, region-aware selection, configured-provider path, active-source visibility, or warning parsing.
- Fix: add a Weather data-source setting with Automatic, QWeather, Open-Meteo, and Caiyun Weather options; Automatic selects QWeather for mainland China only when QWeather credentials are configured and otherwise keeps Open-Meteo as the fallback. QWeather now reads current conditions, hourly forecast, daily high/low, China AQI category, and active weather warnings; the expanded view shows the active source and warning chip.
- Verification: source-selection unit tests cover mainland China, overseas, explicit-provider, and missing-credential fallback behavior.

## 2026-07-16 - QWeather and Caiyun configured credentials do not fetch provider data

- Symptom: QWeather and Caiyun credentials could be entered, but provider data could still fail to load; QWeather air quality and warnings were especially likely to stay empty.
- Cause: QWeather air quality and warning requests still used old v7 paths instead of the current `/airquality/v1/current/{latitude}/{longitude}` and `/weatheralert/v1/current/{latitude}/{longitude}` JWT endpoints, QWeather coordinates used more precision than documented, copied `Bearer ...` tokens were not normalized, AQI index selection did not prefer China's local index, and Caiyun only supported the legacy token URL instead of the current App Key/App Secret signature flow.
- Fix: use two-decimal QWeather coordinates, generate QWeather JWT tokens locally from credential ID, project ID, and Ed25519 private key, route QWeather requests to current air-quality and weather-alert APIs without appending `key=`, prefer China/local AQI indexes before QAQI or US indexes, add Caiyun App Key/App Secret settings, sign Caiyun requests with HMAC-SHA256, and keep legacy Caiyun token fallback.
- Verification: syntax parse passed; localization JSON passed; Caiyun signature unit test matches the official documented example; QWeather JWT generation, PKCS8 private-key parsing, and AQI index selection tests cover the provider-specific regressions.

## 2026-07-16 - Nudge compact time, custom delay, and sound preview controls are incomplete

- Symptom: a two-digit countdown is clipped in minimal compact mode, the custom-minute input is oversized and appears to leave the preset selected, and named or custom sounds do not play when Preview is clicked.
- Cause: the minimal trailing slot did not reserve enough width for localized countdown text; the generic input had no compact submit treatment; and preview reused the delivery-time sound API, which correctly blocks audio when notification sound authorization or settings are unavailable.
- Fix: use shorter compact Chinese units in a fixed-width trailing frame, add an optional compact input with a localized Apply button, and expose a separate named-sound preview API that works only during an explicit extension action.
- Verification: Nudge tests cover a 12-minute compact countdown, the compact Apply input contract, and the preview-specific sound call; JavaScript syntax, extension tests, and the macOS test/build targets pass.

## 2026-07-16 - Agents Status is mistranslated as network proxy status

- Symptom: the Simplified Chinese extension name is shown as “代理状态”, which reads as network proxy status rather than the status of Claude Code and Codex agents.
- Cause: `Agent` was translated literally without preserving the product term used by the extension.
- Fix: use “Agents 状态” for the extension name and “Agent” in its sound-alert description.
- Verification: an extension-localization regression test reads the source manifest and settings JSON and asserts the intended terminology.

## 2026-07-16 - Extension input refresh clears Chinese IME composition

- Symptom: while entering Chinese with a pinyin input method, unfinished composition text disappears unless the user completes it before the next extension refresh.
- Cause: the AppKit input bridge replaced `NSTextView.string` from the SwiftUI binding even while the text view owned marked text, and intercepted Return before the input method could finish composition.
- Fix: preserve marked text during external synchronization and submit Return only when no input-method composition is active.
- Verification: focused input-policy regression tests cover marked-text synchronization, Return submission, and Shift-Return behavior; the extension test suite and macOS build pass.

## 2026-07-16 - Extension install review obscures identity and purpose

- Symptom: the permission list dominates the install sheet, while the extension name and purpose are easy to miss.
- Cause: the sheet used a generic puzzle icon and title; the extension name was secondary monospaced text and its description had no purpose heading.
- Fix: show the extension icon and name as the primary identity, include version, author and ID, and place a labeled purpose section before permissions.
- Verification: localization tests cover the new purpose text, the Nudge manifest test verifies install metadata, and the macOS build passes.

## 2026-07-16 - User extension uninstall is incomplete and lacks a safe UI

- Symptom: the extension manager contains folder copy/delete methods, but Settings exposes no install or uninstall flow; direct uninstall calls can target bundled IDs and leave extension settings and stored data behind.
- Cause: the original methods were development scaffolding without user-facing confirmation, source validation, runtime permission enforcement, or persistence cleanup.
- Fix: add folder selection and permission review from a private staged snapshot, validate IDs, versions, permissions, symbolic links and resource paths, reject conflicts, restrict uninstall to the discovered user extension directory, and remove namespaced data during uninstall.
- Verification: focused installation validation and persistence cleanup tests, localization catalog tests, XcodeGen generation, and the macOS test/build targets pass.

## 2026-07-16 - Shelf rejects text, source-code, and JSON files

- Symptom: folders, images, DMG, ZIP, and font files can be staged, while `.txt`, `.py`, `.json`, and related text-based files are ignored.
- Cause: Finder advertises these files only by content type and without a suggested filename; the fallback path incorrectly required `suggestedName` before loading the file representation.
- Fix: accept source-code and JSON drop types, load content-typed file representations without relying on `suggestedName`, preserve ordinary dragged text as a text snippet, and manage copied files in Shelf storage.
- Verification: Swift parsing, XcodeGen generation, the macOS Debug build, and Finder drag tests for `.txt`, `.py`, and `.json` all pass; existing ZIP and TTF drops remain functional.

## 2026-07-14 - Live Football extension missing from generated app

- Symptom: `Extensions/live-football` existed in the repository but was not copied into the application bundle.
- Cause: the extension was absent from the explicit copy list in `project.yml`.
- Fix: added `live-football` to the bundled-extension copy phase.
- Verification: the generated Debug application contains `Contents/Resources/Extensions/live-football`.

## 2026-07-14 - Extension package-manager drift

- Symptom: project instructions required pnpm, while the WhatsApp provider retained an npm lockfile and the Xcode build phase invoked `npx`.
- Cause: extension tooling had not been migrated with the repository convention.
- Fix: replaced the provider lockfile with `pnpm-lock.yaml`, declared the pnpm version, and changed the build phase to `pnpm dlx esbuild`.
- Verification: pnpm resolves the lockfile offline and the generated application build succeeds.

## 2026-07-14 - Pomodoro pauses when Now Playing changes tracks

- Symptom: while the Pomodoro extension is running, a music track change can switch the active module to Now Playing and make the timer appear paused.
- Cause: Now Playing auto-selected itself whenever the detected media title changed. That made the active extension invisible, so Smart/Low Power extension timer suspension could skip the Pomodoro JS interval.
- Fix: Now Playing only auto-selects on track changes when no active extension is visible, or when the active extension reports itself inactive.
- Verification: Swift parse and macOS unit tests pass.

## 2026-07-15 - Compact collapse exposes the physical notch

- Symptom: when pointer focus leaves the island, the collapse rebound briefly reveals part of the Mac's physical notch.
- Cause: expansion and collapse shared the same spring with positive extra bounce, so collapse could pass beyond the compact bounds.
- Fix: collapse now uses a non-overshooting ease-out animation while expansion keeps the configured spring.
- Verification: macOS unit tests and the generated app build pass.

## 2026-07-15 - Computer Status refresh shifts, re-samples CPU, and flashes the island shadow

- Symptom: the Computer Status layout visibly shifts during refresh, CPU samples can disagree between render states, and the bottom island shadow briefly disappears.
- Cause: one extension refresh renders every supported size, each render requested a fresh CPU delta, and dynamic extension content shared the island background's compositing layer and shadow.
- Fix: cache one native snapshot for the render pass, use fixed-size circular metrics with monospaced values, and keep shadows on an independent island background layer.
- Verification: JavaScript syntax, macOS unit tests, and the generated app build pass.

## 2026-07-15 - Xcode 26 reports source and project warnings

- Symptom: Xcode reports EventKit Sendable captures, a Shelf actor-isolation access, a CoreAudio CFString pointer warning, an updater actor mutation, and outdated recommended settings.
- Cause: legacy Objective-C values crossed an explicitly serialized queue without a Sendable wrapper, and the generated project retained an old Xcode upgrade marker.
- Fix: scoped the EventKit query in an unchecked Sendable value, marked the pure Shelf path helper nonisolated, used an unmanaged CFString output pointer, returned updater cleanup to the main actor, and set XcodeGen's Xcode version.
- Verification: a clean Xcode 26 build emits none of the reported source warnings and generates `LastUpgradeCheck = 2660`.

## 2026-07-15 - Compact extension cycling only shows Pomodoro

- Symptom: compact cycling can appear to lose most bundled extensions, leaving Pomodoro as the only visible extension, while menu-bar and Settings controls disagree after a module is stopped.
- Cause: newly discovered extensions were written into `extensions.userDisabled`; compact drag gestures were ignored; stock and computer-status precedence hid their selected compact views; and the menu cached stale state while duplicating extension activation controls under Modules.
- Fix: discovery only auto-disables manifests with `defaultEnabled=false`; a versioned one-time migration repairs affected defaults; compact horizontal dragging cycles modules again; selected stock and computer-status views retain the compact slot; disabled active modules are replaced immediately; and extension activation now lives only in Extensions settings.
- Verification: JavaScript syntax checks, generated-project build, and macOS unit tests pass.

## 2026-07-15 - Local Apple Silicon DMG packaging stops or fails validation

- Symptom: local packaging exits when no signing certificate is installed; forcing it past that point leaves a universal app with an arm64-only Node runtime and an invalid application signature.
- Cause: `pipefail` treated an empty certificate lookup as fatal, the build explicitly disabled active-architecture selection, and Node was added after Xcode signed the app.
- Fix: tolerate an empty certificate lookup, build the local package explicitly for arm64, and apply an ad-hoc signature after bundling Node when no development certificate is available.
- Verification: the Release build succeeds, the app and Node binaries both report arm64, `codesign --verify --deep --strict` passes, and `hdiutil verify` reports a valid DMG checksum.
