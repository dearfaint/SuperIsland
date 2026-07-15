# SuperIsland Resolved Issues

Record resolved issues with date, symptom, cause, fix, and verification evidence.

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
