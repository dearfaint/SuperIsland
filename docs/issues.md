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
