# SuperIsland Roadmap

## Completed

- [x] Add native localization infrastructure with English fallback and Simplified Chinese translations.
- [x] Localize system permission descriptions and locale-sensitive dates, times, numbers, and units.
- [x] Fix confirmed extension packaging and package-manager documentation drift.
- [x] Verify the generated Xcode project and macOS build.
- [x] Restore Shelf staging for Finder text, source-code, and JSON files without regressing existing file types.

## Approved Next

- [x] Add a localization contract for bundled JavaScript extension metadata, settings, and runtime UI.
- [x] Add focused localization regression tests for representative native screens and formatter output.
- [x] Add a bundled Computer Status extension with read-only aggregate Mac health metrics, including fan RPM.
- [x] Add a bundled HK + A Stocks extension that avoids mainland quote endpoints.

## Proposed - Requires Product Decisions

- [ ] Replace or disable the upstream analytics destination.
- [ ] Confirm the fork's bundle identifier, URL scheme, update repository, signing identity, and OAuth service ownership.
- [ ] Add signature or Team ID verification before automatic update installation.
- [ ] Confirm application-level redistribution licensing before publishing modified builds.
