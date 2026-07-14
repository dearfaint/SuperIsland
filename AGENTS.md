# SuperIsland - Agent Instructions

## Working rules

- Read this file and the relevant project documents before making changes.
- Preserve established code, tooling, and conventions unless the task requires a change.
- Keep modifications focused; do not refactor unrelated code.
- State assumptions when requirements are ambiguous and verify the smallest relevant outcome.
- Before coding, define a concrete success condition and do not silently choose between ambiguous product interpretations.
- Do not add speculative features, one-off abstractions, or unrelated cleanup.
- Every modified line must be traceable to the active request.

## Documentation

- Keep `README.md` accurate for project purpose, setup, and current status.
- Record completed user-visible changes in `CHANGELOG.md`.
- Record material technical decisions in `docs/architecture.md`.
- Record resolved defects with evidence in `docs/issues.md`.
- Keep next work and its status in `docs/roadmap.md`.
- Update only documents materially affected by the task; avoid empty maintenance churn.

## Project-specific constraints

- The app targets macOS 14 or later and uses Swift 5.9, SwiftUI, AppKit, JavaScriptCore, and XcodeGen.
- Generate the Xcode project with `xcodegen generate`; do not hand-edit generated project files.
- Use `pnpm` for extension package management. Do not introduce npm-generated lockfiles or npm commands.
- Prefer Tsinghua mirrors when dependencies must be downloaded.
- Keep built-in module behavior separate from the JavaScript extension-host contract.
- English is the source language. Simplified Chinese uses the `zh-Hans` locale and must fall back to English.
- Localize dates, times, numbers, and measurements with platform formatters rather than translated string fragments.
- Do not change the bundle identifier, URL scheme, analytics destination, OAuth services, signing identity, or update ownership without explicit approval.
- Run the smallest relevant syntax checks, then `xcodegen generate` and `xcodebuild` for changes that affect the app target.
