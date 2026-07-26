# TomatoTimer Agent Rules

Use this file before continuing work on the native macOS TomatoTimer app.

## Project Shape

- Workspace: `/Users/kai/番茄钟app`
- Xcode project: `TomatoTimer.xcodeproj`
- Main scheme: `TomatoTimer`
- Main source directory: `TomatoTimer`

## Operating Rules

- Preserve visible timer behavior unless the user asks otherwise.
- For performance work, measure first in Release. Do not optimize from raw startup
  spikes alone.
- The app intentionally interacts with screen sleep/display behavior. Do not change
  sandbox, sleep, notification, or activity-monitor behavior without verifying the
  affected workflow.
- Keep changes scoped to the requested issue.

## Verification

Run the full gate — lint, both Release builds, tests — before handing work back:

```bash
Scripts/ci.sh
```

Individual stages: `Scripts/ci.sh lint | macos | ios | test`.

Lint config lives in `.swiftlint.yml` (`brew install swiftlint` if missing). It fails
only on error-severity violations; two `file_length` warnings are known, expected debt
on `PomodoroTimerViewModel.swift` and its test file, and should disappear when that view
model is finally split up.

`.github/workflows/ci.yml` runs the same sequence on push/PR at
https://github.com/JamesJoe716/TomatoTimer.

When `CI` is set, `Scripts/ci.sh` switches to ad-hoc code signing, because hosted
runners have no certificate for team `W882AG982U`. Local runs are unaffected and keep
the real signing identity — do not remove that env guard.

Underlying build command, if you need it directly:

```bash
xcodebuild -project /Users/kai/番茄钟app/TomatoTimer.xcodeproj -scheme TomatoTimer -configuration Release build
```

For performance thresholds, warm up the Release app and use Instruments/xctrace or a
specific benchmark before making claims.

## Handoff

Record changed files, commands run, app path checked, and any remaining manual UI
checks in `WORKLOG.md`.
