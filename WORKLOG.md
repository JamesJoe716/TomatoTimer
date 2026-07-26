# TomatoTimer Worklog

## Current State

- Native macOS SwiftUI Pomodoro app.
- Main Xcode scheme: `TomatoTimer`.
- Prior performance pass established that measurement should happen in Release after
  warm-up.

## Acceptance Checklist

- Release xcodebuild succeeds.
- App launches.
- Timer start/pause/reset and selected duration still work.
- Notification/speech/display-sleep behavior still matches the requested workflow if
  touched.
- Performance changes are measured before and after.

## Notes

### 2026-05-24

- Added `AGENTS.md` and this worklog as stable continuation entry points.
- Verified scheme discovery with `xcodebuild -list`.

### 2026-05-25

- Reviewed current project shape for improvement, simplification, and plan
  fidelity. Source code was not changed during the review.
- Commands run:
  - `xcodebuild -project /Users/kai/番茄钟app/TomatoTimer.xcodeproj -scheme TomatoTimer -configuration Release build`
  - `xcodebuild -project /Users/kai/番茄钟app/TomatoTimer.xcodeproj -scheme TomatoTimer -configuration Debug analyze`
  - Resource/package checks under the Release app bundle.
- App path checked:
  `/Users/kai/Library/Developer/Xcode/DerivedData/TomatoTimer-ccscfulxaisamighuyshzpesleja/Build/Products/Release/TomatoTimer.app`
- Manual UI checks remaining: start/pause/reset, countdown adjustment buttons,
  voice-gender switching, break transition display sleep/wake behavior, and
  visible animation behavior after any future simplification.

### 2026-05-31

- Fixed and simplified the high-priority review findings:
  - Countdown adjustment buttons now match their labels: `-` subtracts remaining
    time and `+` adds remaining time.
  - Cached avatar image loading so animation refreshes no longer re-read PNG
    files from disk.
  - Paused the timer face `TimelineView` outside active work/break states.
  - Removed unused timer view-model code and stopped bundling Preview assets in
    the app resources phase.
- Changed files:
  - `TomatoTimer/PomodoroTimerViewModel.swift`
  - `TomatoTimer/ContentView.swift`
  - `TomatoTimer.xcodeproj/project.pbxproj`
  - `WORKLOG.md`
- Commands run:
  - `xcodebuild -project /Users/kai/番茄钟app/TomatoTimer.xcodeproj -scheme TomatoTimer -configuration Release build`
  - `xcodebuild -project /Users/kai/番茄钟app/TomatoTimer.xcodeproj -scheme TomatoTimer -configuration Debug analyze`
  - Release app launch and Computer Use UI inspection.
- App path checked:
  `/Users/kai/Library/Developer/Xcode/DerivedData/TomatoTimer-ccscfulxaisamighuyshzpesleja/Build/Products/Release/TomatoTimer.app`
- Manual UI checks completed: Release app launched; start/reset worked; `-1分`
  reduced remaining time; `+30秒` increased remaining time; avatar rendered.
- Manual UI checks remaining: voice-gender switching and full break-transition
  display sleep/wake behavior.

### 2026-05-31 iOS simulator run

- Added a separate `TomatoTimer-iOS` target and shared scheme so the existing
  macOS `TomatoTimer` scheme remains intact.
- Added iOS-compatible app entry and platform guards around macOS-only AppKit,
  IOKit, display-sleep, and window-presentation behavior.
- Adjusted compact SwiftUI layout for iPhone width: scrollable vertical layout,
  compact duration steppers, smaller mobile avatar, and two-row adjustment
  buttons.
- Added iOS app-icon metadata to the existing `AppIcon` asset set.
- Changed files:
  - `TomatoTimer/TomatoTimeriOSApp.swift`
  - `TomatoTimer/ContentView.swift`
  - `TomatoTimer/PomodoroTimerViewModel.swift`
  - `TomatoTimer/AppActivityMonitor.swift`
  - `TomatoTimer/DisplaySleepAssertion.swift`
  - `TomatoTimer/ScreenSleeper.swift`
  - `TomatoTimer/Assets.xcassets/AppIcon.appiconset/Contents.json`
  - `TomatoTimer.xcodeproj/project.pbxproj`
  - `TomatoTimer.xcodeproj/xcshareddata/xcschemes/TomatoTimer-iOS.xcscheme`
  - `WORKLOG.md`
- Commands/tools run:
  - `xcodebuild -project /Users/kai/番茄钟app/TomatoTimer.xcodeproj -list`
  - XcodeBuildMCP `list_schemes`, `list_sims`, `session_set_defaults`, and
    `build_run_sim` for `TomatoTimer-iOS` on iPhone 17 Pro
    (`F16EDCC5-9DB5-4C29-BCE0-AF8E3E8C3D77`, iOS 26.5).
  - `xcodebuild -project /Users/kai/番茄钟app/TomatoTimer.xcodeproj -scheme TomatoTimer-iOS -configuration Release -destination 'platform=iOS Simulator,id=F16EDCC5-9DB5-4C29-BCE0-AF8E3E8C3D77' build`
  - `xcodebuild -project /Users/kai/番茄钟app/TomatoTimer.xcodeproj -scheme TomatoTimer -configuration Release build`
- App paths checked:
  - iOS Debug simulator app:
    `/Users/kai/Library/Developer/XcodeBuildMCP/workspaces/app-64756e0697f1/DerivedData/TomatoTimer-33ec7c745caa/Build/Products/Debug-iphonesimulator/TomatoTimer.app`
  - iOS Release simulator app:
    `/Users/kai/Library/Developer/Xcode/DerivedData/TomatoTimer-ccscfulxaisamighuyshzpesleja/Build/Products/Release-iphonesimulator/TomatoTimer.app`
  - macOS Release app:
    `/Users/kai/Library/Developer/Xcode/DerivedData/TomatoTimer-ccscfulxaisamighuyshzpesleja/Build/Products/Release/TomatoTimer.app`
- Manual UI checks completed: iOS app launched on iPhone 17 Pro simulator;
  screenshot and accessibility hierarchy captured; compact layout no longer
  clips horizontally; scrolling reveals controls; tapping `开始` changed status
  to `进行中` and countdown advanced.
- Manual UI checks remaining: iOS voice-gender switching/audio playback and full
  break transition. macOS display sleep/wake workflow was not re-tested because
  iOS support only added platform guards around those existing macOS behaviors.

### 2026-06-01 iPhone 17 Pro Max preparation

- Updated the `TomatoTimer-iOS` target signing settings for Debug and Release:
  automatic signing, Apple Development identity, and development team
  `QCFMVJ74ZY`. The macOS `TomatoTimer` target signing settings were left
  unchanged.
- Current blocker for physical iPhone install: `xcrun devicectl list devices`
  reported no connected devices, and signed `iphoneos` build failed because
  Xcode has no account for team `QCFMVJ74ZY` and no provisioning profile for
  `com.kai.TomatoTimer.ios`.
- Changed files:
  - `TomatoTimer.xcodeproj/project.pbxproj`
  - `WORKLOG.md`
- Commands/tools run:
  - `xcodebuild -project /Users/kai/番茄钟app/TomatoTimer.xcodeproj -list`
  - `xcrun xctrace list devices`
  - XcodeBuildMCP `session_set_defaults` and `build_run_sim` for
    `TomatoTimer-iOS` on iPhone 17 Pro Max simulator
    (`AFA4DB08-859F-4FCD-98DC-4C94DCF43990`, iOS 26.5).
  - `xcrun devicectl list devices`
  - `security find-identity -v -p codesigning`
  - `xcodebuild -project /Users/kai/番茄钟app/TomatoTimer.xcodeproj -scheme TomatoTimer-iOS -configuration Release -showBuildSettings`
  - `xcodebuild -project /Users/kai/番茄钟app/TomatoTimer.xcodeproj -scheme TomatoTimer-iOS -configuration Release -destination 'generic/platform=iOS' -allowProvisioningUpdates build`
  - `xcodebuild -project /Users/kai/番茄钟app/TomatoTimer.xcodeproj -scheme TomatoTimer-iOS -configuration Release -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build`
  - `xcodebuild -project /Users/kai/番茄钟app/TomatoTimer.xcodeproj -scheme TomatoTimer-iOS -configuration Release -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.5' build`
  - `xcodebuild -project /Users/kai/番茄钟app/TomatoTimer.xcodeproj -scheme TomatoTimer -configuration Release build`
- App paths checked:
  - iPhone simulator Release app:
    `/Users/kai/Library/Developer/XcodeBuildMCP/workspaces/app-64756e0697f1/DerivedData/TomatoTimer-33ec7c745caa/Build/Products/Release-iphonesimulator/TomatoTimer.app`
  - unsigned physical-device Release build:
    `/tmp/TomatoTimer-iPhoneDevice-NoSign/Build/Products/Release-iphoneos/TomatoTimer.app`
  - macOS Release app:
    `/tmp/TomatoTimerMacAfterIOSSigning/Build/Products/Release/TomatoTimer.app`
- Manual UI checks completed: iPhone 17 Pro Max simulator launched; screenshot
  and accessibility hierarchy captured; scrolling revealed lower controls;
  tapping `开始` changed status to `进行中` and countdown advanced.
- Manual UI checks remaining: physical iPhone install/launch after Xcode account
  and provisioning are available; iOS voice-gender switching/audio playback; full
  break transition.

### 2026-06-27 six-agent repair pass

- Ran six parallel review slices covering timer/domain behavior, SwiftUI
  frontend/accessibility, macOS platform behavior, iOS/device readiness, code
  quality, and build/verification.
- Fixed timer and speech behavior:
  - Break display sleep is now guarded by a break-session token so stale speech
    callbacks cannot sleep the display after reset/skip.
  - Changing voice gender preserves pending completion handlers instead of
    canceling break display-sleep follow-up work.
  - Paused countdown adjustment to zero no longer starts a break or sleeps the
    display.
  - Long sessions beyond 120 minutes now fall back to synthesized milestone
    speech instead of dropping the elapsed-minute announcement.
  - iOS now configures an `AVAudioSession` for spoken/audio timer prompts.
- Fixed frontend and accessibility issues:
  - Compact layout now prioritizes the timer before the avatar.
  - macOS minimum window size lowered so compact layout is reachable.
  - Timer face exposes a combined accessibility label/value with state,
    remaining time, selected duration, and progress.
  - Preset duration segments include minute units.
  - Button labels and timer text gained scaling/line limits to reduce clipping.
  - Progress/avatar animation paths respect Reduce Motion more consistently.
- Fixed macOS platform/code-quality issues:
  - Dock reopen handling no longer falls through to duplicate default handling.
  - Fallback main window is strongly retained and has the same lower minimum
    size as the SwiftUI content.
  - App startup configures the fallback presenter before any window appears and
    attempts to create a main window if launch produces no visible window.
  - Injected notification centers are now removed symmetrically on deinit.
  - Display sleep assertion and `pmset displaysleepnow` failures are logged.
  - Release speech-event logging is debug-gated.
- Changed files:
  - `TomatoTimer/ContentView.swift`
  - `TomatoTimer/PomodoroTimerViewModel.swift`
  - `TomatoTimer/SpeechNotifier.swift`
  - `TomatoTimer/AppActivityMonitor.swift`
  - `TomatoTimer/TomatoTimerApp.swift`
  - `TomatoTimer/DisplaySleepAssertion.swift`
  - `TomatoTimer/ScreenSleeper.swift`
  - `WORKLOG.md`
- Commands/tools run:
  - `security find-identity -v -p codesigning`
  - `xcodebuild -project /Users/kai/番茄钟app/TomatoTimer.xcodeproj -scheme TomatoTimer -configuration Release -derivedDataPath /tmp/TomatoTimerFinal5MacRelease build`
  - `xcodebuild -project /Users/kai/番茄钟app/TomatoTimer.xcodeproj -scheme TomatoTimer -configuration Debug -derivedDataPath /tmp/TomatoTimerFinal5MacAnalyze analyze`
  - `xcodebuild -project /Users/kai/番茄钟app/TomatoTimer.xcodeproj -scheme TomatoTimer-iOS -configuration Release -destination 'generic/platform=iOS' -derivedDataPath /tmp/TomatoTimerFinal5iOSNoSign CODE_SIGNING_ALLOWED=NO build`
  - `xcodebuild -project /Users/kai/番茄钟app/TomatoTimer.xcodeproj -scheme TomatoTimer -configuration Release build`
  - `codesign --verify --deep --strict --verbose=2` on built and installed app
    bundles.
  - `spctl --assess --type execute --verbose=4 /Applications/TomatoTimer.app`
  - `/usr/sbin/DevToolsSecurity -status`
  - Real launch attempts with `open -n`, direct executable launch, and LLDB,
    plus `log stream` / `log show` checks for AMFI and AppleSystemPolicy.
- App paths checked:
  - macOS Release build:
    `/tmp/TomatoTimerFinal5MacRelease/Build/Products/Release/TomatoTimer.app`
  - installed macOS app:
    `/Applications/TomatoTimer.app`
  - default DerivedData Release app:
    `/Users/kai/Library/Developer/Xcode/DerivedData/TomatoTimer-ccscfulxaisamighuyshzpesleja/Build/Products/Release/TomatoTimer.app`
  - unsigned generic iOS device build:
    `/tmp/TomatoTimerFinal5iOSNoSign/Build/Products/Release-iphoneos/TomatoTimer.app`
- Installation state:
  - Installed a rebuilt `/Applications/TomatoTimer.app`.
  - Previous `/Applications/TomatoTimer.app` copies were preserved as:
    `/Applications/TomatoTimer.app.backup-20260627-112207` and
    `/Applications/TomatoTimer.app.backup-20260627-112456`.
- Verification result:
  - macOS Release build succeeded.
  - macOS Debug static analysis succeeded.
  - unsigned generic physical-device iOS Release build succeeded.
  - Xcode/CoreSimulator still reports a local toolchain mismatch:
    CoreSimulator `1051.54.0` is older than Xcode's expected `1051.55.0`.
  - Initial macOS launch attempts were blocked by system policy before app code
    ran because `DevToolsSecurity -status` reported Developer Mode disabled.
  - Follow-up check after Developer Mode was enabled: `/Applications/TomatoTimer.app`
    launched successfully, stayed running, and presented the `番茄钟` window.
- Manual UI checks completed: code was rebuilt; app bundles/signatures were
  verified; launch attempts were captured with screenshots and system logs;
  after Developer Mode was enabled, the installed macOS app launched to the
  visible idle timer screen.
- Manual UI checks remaining: timer/break/speech interaction smoke test after
  any future behavior change.

### 2026-07-04 adversarial repair pass

- Fixed concurrency and lifecycle issues under complete strict concurrency:
  - MainActor-owned app activity and timer objects now use isolated deinits for
    observer/timer cleanup.
  - Speech callbacks, app-activity notifications, screen-sleep completions, and
    timer ticks are routed back through MainActor boundaries.
  - Removed the remaining unchecked-sendable speech notifier shape.
- Fixed timer behavior and system-failure surfacing:
  - Paused countdown adjustment to zero now enters break instead of leaving an
    invalid zero countdown state.
  - Display sleep and wake failures publish a visible system notice instead of
    only logging.
  - Break start requests user attention without forcibly focusing the app when
    another app is active.
- Fixed frontend/accessibility issues:
  - Reduce Motion now pauses timer/avatar animation timelines.
  - Timer text and compact controls use scaling/line limits instead of fixed
    clipping.
  - iPhone compact layout now shows the avatar fully at default size.
  - Mobile duration controls were replaced with fixed icon controls so large
    accessibility text no longer wraps `00`/`25` vertically.
- Added regression coverage:
  - New macOS and iOS unit test targets.
  - Shared tests for zero-adjust break transition, break reset, sleep-failure
    notices, and voice-change completion preservation.
- Signing/build configuration:
  - Enabled complete Swift strict concurrency for app and test targets.
  - macOS Release now builds with Apple Development signing, hardened runtime,
    and empty entitlements instead of ad-hoc Release signing.
  - iOS Release device build succeeds with automatic provisioning for
    `com.kai.TomatoTimer.ios`.
  - Formal Developer ID signing and notarization could not be completed because
    this Mac has no `Developer ID Application` signing identity installed.
- Changed files:
  - `TomatoTimer/ContentView.swift`
  - `TomatoTimer/PomodoroTimerViewModel.swift`
  - `TomatoTimer/SpeechNotifier.swift`
  - `TomatoTimer/AppActivityMonitor.swift`
  - `TomatoTimer/TomatoTimerApp.swift`
  - `TomatoTimer/DisplaySleepAssertion.swift`
  - `TomatoTimer/ScreenSleeper.swift`
  - `TomatoTimerTests/PomodoroTimerViewModelTests.swift`
  - `TomatoTimer.xcodeproj/project.pbxproj`
  - `TomatoTimer.xcodeproj/xcshareddata/xcschemes/TomatoTimer.xcscheme`
  - `TomatoTimer.xcodeproj/xcshareddata/xcschemes/TomatoTimer-iOS.xcscheme`
  - `WORKLOG.md`
- Commands/tools run:
  - `xcodebuild -project /Users/kai/番茄钟app/TomatoTimer.xcodeproj -scheme TomatoTimer -configuration Debug -derivedDataPath /tmp/TomatoTimerMacTestFinal test`
  - `xcodebuild -project /Users/kai/番茄钟app/TomatoTimer.xcodeproj -scheme TomatoTimer-iOS -configuration Debug -destination 'id=AFA4DB08-859F-4FCD-98DC-4C94DCF43990' -derivedDataPath /tmp/TomatoTimerIOSTestFinal CODE_SIGNING_ALLOWED=NO test`
  - `xcodebuild -project /Users/kai/番茄钟app/TomatoTimer.xcodeproj -scheme TomatoTimer -configuration Release -derivedDataPath /tmp/TomatoTimerMacReleaseFinal build`
  - `xcodebuild -project /Users/kai/番茄钟app/TomatoTimer.xcodeproj -scheme TomatoTimer-iOS -configuration Release -destination 'generic/platform=iOS' -derivedDataPath /tmp/TomatoTimerIOSReleaseFinal -allowProvisioningUpdates build`
  - `xcodebuild -project /Users/kai/番茄钟app/TomatoTimer.xcodeproj -scheme TomatoTimer -configuration Debug -derivedDataPath /tmp/TomatoTimerAnalyzeFinal analyze`
  - `codesign -dv --verbose=4 /tmp/TomatoTimerMacReleaseFinal/Build/Products/Release/TomatoTimer.app`
  - `codesign -d --entitlements :- /tmp/TomatoTimerMacReleaseFinal/Build/Products/Release/TomatoTimer.app`
  - `spctl --assess --type execute --verbose=4 /tmp/TomatoTimerMacReleaseFinal/Build/Products/Release/TomatoTimer.app`
  - `security find-identity -v -p codesigning`
  - `xcrun simctl install/launch/io screenshot/ui content_size` on iPhone 17 Pro
    Max simulator `AFA4DB08-859F-4FCD-98DC-4C94DCF43990`.
  - `plutil -lint` for `TomatoTimer/Info.plist` and
    `TomatoTimer/TomatoTimer.entitlements`.
  - Static scan with `rg` for `@unchecked`, `fatalError`, `try!`, `as!`,
    `TODO`, `FIXME`, `DispatchQueue`, and `Thread.sleep`.
- App paths checked:
  - macOS Release build:
    `/tmp/TomatoTimerMacReleaseFinal/Build/Products/Release/TomatoTimer.app`
  - iOS simulator Debug app:
    `/tmp/TomatoTimerIOSVisual/Build/Products/Debug-iphonesimulator/TomatoTimer.app`
  - iOS device Release build:
    `/tmp/TomatoTimerIOSReleaseFinal/Build/Products/Release-iphoneos/TomatoTimer.app`
- Manual UI checks completed:
  - iPhone 17 Pro Max simulator default-size screenshot:
    `/tmp/tomato_ios_home_final.png`.
  - iPhone 17 Pro Max simulator accessibility-extra-large screenshot:
    `/tmp/tomato_ios_accessibility_large_after_stepper.png`.
  - Default compact layout has no obvious overlap and avatar is fully visible.
  - Accessibility-extra-large layout keeps compact duration values horizontal;
    lower content remains reachable by vertical scrolling.
- Verification result:
  - macOS Debug tests passed: 4 tests, 0 failures.
  - iOS simulator Debug tests passed: 4 tests, 0 failures.
  - macOS Debug static analysis succeeded.
  - macOS Release build succeeded with hardened runtime and empty entitlements.
  - iOS generic device Release build succeeded with provisioning profile.
  - `spctl` still rejects the macOS Release app because it is not Developer ID
    signed/notarized.
- Manual UI checks remaining: physical iPhone install/launch was not rerun
  because `xctrace` reported the connected iPhone as offline during this pass.

### 2026-07-04 first-principles adversarial defect repair follow-up

- Fixed lifecycle/screen-sleep race:
  - `ScreenSleeper` now returns cancellable sleep requests.
  - Reset/skip during break cancels pending display-sleep work and ignores late
    completions.
  - `Process.run()` startup is locked with cancellation so a reset cannot race
    between process assignment and `pmset displaysleepnow`.
- Fixed SwiftUI/front-end maintainability and Swift 6 build failure:
  - Split `ContentView` into `TimerColumnView`, `TimerFaceView`, and
    `DigitalAvatarView`.
  - Reworked duration controls to avoid Swift 6 IRGen crashes from actor-isolated
    `Binding` setter reabstraction.
  - iPhone compact/short-height layouts now use a scrollable vertical layout;
    system notice and duration controls have explicit accessibility labels,
    values, and 44-point touch targets.
- Added release hygiene:
  - Added `.gitignore`.
  - Removed `.DS_Store`, Xcode user-state files, and the avatar quarantine xattr.
  - Added `TomatoTimer/PrivacyInfo.xcprivacy` to macOS and iOS app resources for
    UserDefaults/AppStorage required-reason API declaration.
- Added tests:
  - Screen sleep cancellation/late completion coverage for reset and skip.
  - Speech-completion race coverage before sleep request.
  - Timer state/editing/countdown boundary coverage.
  - Bundle audio-resource playback coverage for all shipped voice clips.
- Changed files:
  - `.gitignore`
  - `TomatoTimer/ContentView.swift`
  - `TomatoTimer/TimerColumnView.swift`
  - `TomatoTimer/TimerFaceView.swift`
  - `TomatoTimer/DigitalAvatarView.swift`
  - `TomatoTimer/PomodoroTimerViewModel.swift`
  - `TomatoTimer/ScreenSleeper.swift`
  - `TomatoTimer/TomatoTimerApp.swift`
  - `TomatoTimer/PrivacyInfo.xcprivacy`
  - `TomatoTimerTests/PomodoroTimerViewModelTests.swift`
  - `TomatoTimerTests/AudioResourceTests.swift`
  - `TomatoTimer.xcodeproj/project.pbxproj`
  - `WORKLOG.md`
- Commands run:
  - `xcodebuild -project /Users/kai/番茄钟app/TomatoTimer.xcodeproj -scheme TomatoTimer -configuration Debug -derivedDataPath /tmp/TomatoFinalCurrentMacTest test`
  - `xcodebuild -project /Users/kai/番茄钟app/TomatoTimer.xcodeproj -scheme TomatoTimer-iOS -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -derivedDataPath /tmp/TomatoFinalCurrentIOSTest CODE_SIGNING_ALLOWED=NO test`
  - `xcodebuild -project /Users/kai/番茄钟app/TomatoTimer.xcodeproj -scheme TomatoTimer -configuration Debug -derivedDataPath /tmp/TomatoFinalAnalyze analyze`
  - `xcodebuild -project /Users/kai/番茄钟app/TomatoTimer.xcodeproj -scheme TomatoTimer -configuration Debug -derivedDataPath /tmp/TomatoFinalNoStepperSwift6Mac SWIFT_VERSION=6.0 build`
  - `xcodebuild -project /Users/kai/番茄钟app/TomatoTimer.xcodeproj -scheme TomatoTimer-iOS -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -derivedDataPath /tmp/TomatoFinalSwift6IOS CODE_SIGNING_ALLOWED=NO SWIFT_VERSION=6.0 build`
  - `xcodebuild -project /Users/kai/番茄钟app/TomatoTimer.xcodeproj -scheme TomatoTimer -configuration Release -derivedDataPath /tmp/TomatoFinalMacRelease3 build`
  - `xcodebuild -project /Users/kai/番茄钟app/TomatoTimer.xcodeproj -scheme TomatoTimer-iOS -configuration Release -destination 'generic/platform=iOS' -derivedDataPath /tmp/TomatoFinalIOSRelease build`
  - `codesign --verify --deep --strict --verbose=2` on macOS, iOS, and installed app bundles.
  - `spctl --assess --type execute --verbose=4 /tmp/TomatoFinalMacRelease3/Build/Products/Release/TomatoTimer.app`
  - `xcrun devicectl device install app --device 20BCB43C-3C7F-5095-9394-209AE86C8EAF /tmp/TomatoFinalIOSRelease/Build/Products/Release-iphoneos/TomatoTimer.app`
- App paths checked:
  - Installed macOS app: `/Applications/TomatoTimer.app`
  - macOS Release build: `/tmp/TomatoFinalMacRelease3/Build/Products/Release/TomatoTimer.app`
  - iOS device Release build: `/tmp/TomatoFinalIOSRelease/Build/Products/Release-iphoneos/TomatoTimer.app`
- Verification result:
  - macOS Debug tests passed: 14 tests, 0 failures.
  - iOS simulator Debug tests passed: 14 tests, 0 failures.
  - macOS Debug static analysis succeeded.
  - macOS and iOS Swift 6 Debug builds succeeded.
  - macOS and iOS Release builds succeeded.
  - Privacy manifest is present in both built app bundles.
  - `/Applications/TomatoTimer.app` was replaced with the current Release app,
    codesign-verified, and launched successfully.
- Remaining external blockers:
  - macOS `spctl` still rejects the Release app for ordinary distribution
    because this Mac only has Apple Development signing and no Developer ID
    Application certificate/notarization.
  - Physical iPhone install failed with `Developer Mode is disabled`; the Mac
    cannot enable this through `devicectl`.

### 2026-07-04 first-principles adversarial defect repair completion

- Fixed the remaining review findings from the follow-up defect hunt:
  - iOS now has a local notification scheduler for work-finished and
    break-finished events, plus scene lifecycle refresh hooks so lock/background
    elapsed time is reconciled on return.
  - The timer state machine no longer carries the unreachable `.finished` state.
  - Display sleep assertion release is balanced so pause/resume/finish paths do
    not over-release the controller.
  - Project build settings now use Swift language version 6.0 instead of relying
    on command-line overrides.
  - Split the remaining SwiftUI/helper types into focused files for timer face,
    progress ring, floating lights, avatar presentation, and avatar image
    loading.
- Changed files:
  - `TomatoTimer/TimerNotificationScheduler.swift`
  - `TomatoTimer/PomodoroTimerViewModel.swift`
  - `TomatoTimer/TomatoTimeriOSApp.swift`
  - `TomatoTimer/ContentView.swift`
  - `TomatoTimer/TimerColumnView.swift`
  - `TomatoTimer/TimerFaceView.swift`
  - `TomatoTimer/TimerFaceFrame.swift`
  - `TomatoTimer/TimerProgressRing.swift`
  - `TomatoTimer/TimerFaceLabels.swift`
  - `TomatoTimer/FloatingLight.swift`
  - `TomatoTimer/FloatingLightsView.swift`
  - `TomatoTimer/DigitalAvatarView.swift`
  - `TomatoTimer/DigitalAvatarPresentation.swift`
  - `TomatoTimer/DigitalAvatarFrame.swift`
  - `TomatoTimer/DigitalAvatarImage.swift`
  - `TomatoTimer/PlatformAvatarImageView.swift`
  - `TomatoTimer/AvatarImageLoader.swift`
  - `TomatoTimer/AvatarSpeechController.swift`
  - `TomatoTimer/AdaptiveLayoutMetrics.swift`
  - `TomatoTimer/VoiceGender+Avatar.swift`
  - `TomatoTimerTests/PomodoroTimerViewModelTests.swift`
  - `TomatoTimer.xcodeproj/project.pbxproj`
  - `WORKLOG.md`
- Commands run:
  - `xcodebuild -project /Users/kai/番茄钟app/TomatoTimer.xcodeproj -scheme TomatoTimer -configuration Debug -derivedDataPath /tmp/TomatoFixAllMacTest3 test`
  - `xcodebuild -project /Users/kai/番茄钟app/TomatoTimer.xcodeproj -scheme TomatoTimer-iOS -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -derivedDataPath /tmp/TomatoFixAllIOSTest CODE_SIGNING_ALLOWED=NO test`
  - `xcodebuild -project /Users/kai/番茄钟app/TomatoTimer.xcodeproj -scheme TomatoTimer -configuration Debug -derivedDataPath /tmp/TomatoFixAllAnalyze analyze`
  - `xcodebuild -project /Users/kai/番茄钟app/TomatoTimer.xcodeproj -scheme TomatoTimer -configuration Release -derivedDataPath /tmp/TomatoFixAllMacRelease build`
  - `xcodebuild -project /Users/kai/番茄钟app/TomatoTimer.xcodeproj -scheme TomatoTimer-iOS -configuration Release -destination 'generic/platform=iOS' -derivedDataPath /tmp/TomatoFixAllIOSRelease build`
  - `codesign --verify --deep --strict --verbose=2` on macOS, iOS, and installed app bundles.
  - `plutil -lint` for source and built `PrivacyInfo.xcprivacy` files.
  - Static scans for `.finished`, `SWIFT_VERSION = 5.0`, helper types left in
    the large SwiftUI files, and generated junk files.
  - `xcrun devicectl list devices`
  - `xcrun devicectl device install app --device 20BCB43C-3C7F-5095-9394-209AE86C8EAF /tmp/TomatoFixAllIOSRelease/Build/Products/Release-iphoneos/TomatoTimer.app`
- App paths checked:
  - Installed macOS app: `/Applications/TomatoTimer.app`
  - macOS Release build: `/tmp/TomatoFixAllMacRelease/Build/Products/Release/TomatoTimer.app`
  - iOS device Release build: `/tmp/TomatoFixAllIOSRelease/Build/Products/Release-iphoneos/TomatoTimer.app`
- Verification result:
  - macOS Debug tests passed: 17 tests, 0 failures.
  - iOS simulator Debug tests passed: 17 tests, 0 failures.
  - macOS Debug static analysis succeeded.
  - macOS and iOS Release builds succeeded.
  - Release build settings report Swift 6.0 / effective Swift 6 and complete
    strict concurrency.
  - macOS and iOS Release app bundles pass `codesign --verify`.
  - Privacy manifest is present and valid in source, built, and installed app
    bundles.
  - `/Applications/TomatoTimer.app` was replaced with the current Release app,
    codesign-verified, and launched successfully.
- Remaining external blockers:
  - Physical iPhone `Kevin Durant` is available/paired, but install still fails
    with `Developer Mode is disabled`; this must be enabled on the phone.
  - Ordinary macOS distribution outside this machine still needs a
    `Developer ID Application` certificate and notarization.

### 2026-07-04 first-principles adversarial defect review

- Scope: read-only first-principles/adversarial review after the completion
  pass. No source fixes were applied.
- Confirmed defects found:
  - iOS lock/background path schedules only the work-finished notification
    before suspension; break-finished notification is scheduled only after the
    app code later enters `.breaking`, so a suspended app can miss the break-end
    alert entirely.
  - `TimerNotificationScheduler` launches untracked async scheduling tasks; a
    reset/pause cancellation can remove current pending notifications, then an
    older task can still add a stale notification after authorization returns.
  - Release iOS device build has code coverage instrumentation enabled;
    `ENABLE_CODE_COVERAGE = YES` and the built binary contains
    `__llvm_prf_*`/`__llvm_cov*` sections.
  - iPhone 17 Pro Max accessibility-extra-extra-extra-large screenshot still
    truncates compact countdown adjustment text, e.g. `-30秒` appears as
    `-3...`.
  - Maintainability debt remains in multi-type files and view builder helper
    methods that the SwiftUI review rules flag for extraction.
- Commands run:
  - `xcodebuild -project /Users/kai/番茄钟app/TomatoTimer.xcodeproj -scheme TomatoTimer -configuration Debug -derivedDataPath /tmp/TomatoAuditMacTest test`
  - `xcodebuild -project /Users/kai/番茄钟app/TomatoTimer.xcodeproj -scheme TomatoTimer-iOS -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -derivedDataPath /tmp/TomatoAuditIOSTest CODE_SIGNING_ALLOWED=NO test`
  - `xcodebuild -project /Users/kai/番茄钟app/TomatoTimer.xcodeproj -scheme TomatoTimer -configuration Debug -derivedDataPath /tmp/TomatoAuditAnalyze analyze`
  - `xcodebuild -project /Users/kai/番茄钟app/TomatoTimer.xcodeproj -scheme TomatoTimer -configuration Release -derivedDataPath /tmp/TomatoAuditMacRelease build`
  - `xcodebuild -project /Users/kai/番茄钟app/TomatoTimer.xcodeproj -scheme TomatoTimer-iOS -configuration Release -destination 'generic/platform=iOS' -derivedDataPath /tmp/TomatoAuditIOSRelease build`
  - `xcodebuild -project /Users/kai/番茄钟app/TomatoTimer.xcodeproj -target TomatoTimer-iOS -configuration Release -showBuildSettings`
  - `xcrun llvm-objdump --section-headers /tmp/TomatoAuditIOSRelease/Build/Products/Release-iphoneos/TomatoTimer.app/TomatoTimer`
  - `codesign --verify --deep --strict --verbose=2` on the audit macOS and iOS
    Release app bundles.
  - `plutil -lint` on `Info.plist`, entitlements, privacy manifest, and
    `project.pbxproj`.
  - `xcrun simctl install/launch/io screenshot/ui content_size` on iPhone 17
    Pro Max simulator `AFA4DB08-859F-4FCD-98DC-4C94DCF43990`.
- App paths checked:
  - macOS Release audit build:
    `/tmp/TomatoAuditMacRelease/Build/Products/Release/TomatoTimer.app`
  - iOS device Release audit build:
    `/tmp/TomatoAuditIOSRelease/Build/Products/Release-iphoneos/TomatoTimer.app`
  - iOS simulator Debug audit app:
    `/tmp/TomatoAuditIOSTest/Build/Products/Debug-iphonesimulator/TomatoTimer.app`
- Verification baseline:
  - macOS Debug tests passed: 17 tests, 0 failures.
  - iOS simulator Debug tests passed: 17 tests, 0 failures.
  - macOS Debug static analysis succeeded.
  - macOS and iOS Release builds succeeded.
  - macOS and iOS Release app bundles pass `codesign --verify`.
- Manual UI evidence:
  - Default screenshot: `/tmp/tomato_audit_normal.png`.
  - Accessibility extra-extra-extra-large screenshot: `/tmp/tomato_audit_ax.png`.

### 2026-07-04 first-principles adversarial defect repair closure

- Fixed all defects found in the preceding adversarial review:
  - iOS running timers now pre-schedule both work-finished and break-finished
    local notifications, so a suspended app can still alert after the break.
  - `TimerNotificationScheduler` now cancels and versions async scheduling work,
    preventing older authorization/add-request tasks from re-adding stale
    notifications after reset or pause.
  - Release code coverage instrumentation is explicitly disabled across app and
    test build configurations.
  - iPhone large accessibility text uses single-column countdown adjustment
    controls with stable button sizing and scaling.
  - Remaining multi-type/helper-heavy SwiftUI and platform files were split into
    focused source files.
- Changed files:
  - `TomatoTimer/PomodoroTimerViewModel.swift`
  - `TomatoTimer/TimerNotificationScheduler.swift`
  - `TomatoTimer/AdaptiveLayoutMetrics.swift`
  - `TomatoTimer/TimerColumnView.swift`
  - `TomatoTimer/SpeechNotifier.swift`
  - `TomatoTimer/TomatoTimerApp.swift`
  - `TomatoTimer/ScreenSleeper.swift`
  - `TomatoTimer/ContentView.swift`
  - `TomatoTimer/DigitalAvatarImage.swift`
  - `TomatoTimerTests/PomodoroTimerViewModelTests.swift`
  - `TomatoTimer.xcodeproj/project.pbxproj`
  - New focused source files for timer state, snapshots, speech interfaces,
    app/window presentation, cancellable screen-sleep requests, duration
    controls, timer actions, countdown adjustments, avatar section, and avatar
    drawing helpers.
- Commands run:
  - `plutil -lint TomatoTimer.xcodeproj/project.pbxproj`
  - `xcodebuild -project /Users/kai/番茄钟app/TomatoTimer.xcodeproj -scheme TomatoTimer -destination 'platform=macOS' test`
  - `xcodebuild -project /Users/kai/番茄钟app/TomatoTimer.xcodeproj -target TomatoTimer-iOS -configuration Debug -sdk iphonesimulator build`
  - `xcodebuild -project /Users/kai/番茄钟app/TomatoTimer.xcodeproj -scheme TomatoTimer -configuration Release build`
  - `xcodebuild -project /Users/kai/番茄钟app/TomatoTimer.xcodeproj -target TomatoTimer-iOS -configuration Release -sdk iphoneos CODE_SIGNING_ALLOWED=NO build`
  - `xcodebuild -project /Users/kai/番茄钟app/TomatoTimer.xcodeproj -target TomatoTimer-iOS -configuration Release -showBuildSettings`
  - `llvm-objdump -h /Users/kai/番茄钟app/build/Release-iphoneos/TomatoTimer.app/TomatoTimer`
  - Static scans for stale notification helper calls, Release coverage sections,
    and remaining private `some View` helper methods.
  - `xcrun simctl` boot/install/launch/screenshot/content-size commands on
    iPhone 17 Pro Max simulator `AFA4DB08-859F-4FCD-98DC-4C94DCF43990`.
- App paths checked:
  - iOS device Release no-sign build:
    `/Users/kai/番茄钟app/build/Release-iphoneos/TomatoTimer.app`
  - iOS simulator Debug app installed on iPhone 17 Pro Max simulator.
  - macOS Release app from the default DerivedData build path.
- Verification result:
  - macOS tests passed: 17 tests, 0 failures.
  - iOS simulator Debug build passed.
  - macOS Release build passed.
  - iOS device Release no-sign build passed.
  - iOS Release build settings report `ENABLE_CODE_COVERAGE = NO`.
  - iOS Release binary has no `__llvm_cov` or `__llvm_prf` sections.
  - iPhone 17 Pro Max accessibility-extra-extra-extra-large screenshot
    `/tmp/tomato_ax_after.png` shows the visible adjustment controls no longer
    truncate or overlap.
- Manual UI checks remaining: none for the code defects addressed in this pass.
  External signing/device gates remain unchanged: ordinary distribution still
  needs Developer ID notarization, and physical iPhone installs still require
  Developer Mode enabled on the device.

### 2026-07-26

- Frontend upgrade pass (scoped to presentation layer; no timer/sleep/notification
  behavior changed). All additions live in files already in the targets — no new
  files, no `project.pbxproj` edits.
- Changes:
  - Cross-platform sensory/haptic feedback on timer state transitions
    (`ContentView.swift`, `TimerSensoryFeedbackModifier`, gated
    `#available(macOS 14.0, iOS 17.0, *)` because the macOS target deploys to 13.0).
  - macOS global keyboard shortcuts via hidden buttons in `ContentView.swift`:
    Space = start/pause toggle, `R` = reset, `S` = skip break. Each routes through
    existing VM methods, which self-guard by state.
  - macOS `MenuBarExtra` (`TomatoTimerApp.swift`): menu-bar label shows a live
    countdown (`🍅 mm:ss`) while active / `timer` symbol when idle; `.window`-style
    popover `MenuBarTimerView` reuses `TimerProgressRing` for a mini control panel
    (primary toggle, reset, open main window via `AppWindowPresenter.requestAttention`).
  - Animated system-notice enter/exit in `TimerHeaderView.swift`
    (spring + move/opacity transition instead of a hard cut).
- Commands run:
  - `xcodebuild -project TomatoTimer.xcodeproj -scheme TomatoTimer -configuration Release build` → BUILD SUCCEEDED
  - `xcodebuild -project TomatoTimer.xcodeproj -scheme TomatoTimer-iOS -configuration Release -destination 'generic/platform=iOS Simulator' build` → BUILD SUCCEEDED
  - `xcodebuild -project TomatoTimer.xcodeproj -scheme TomatoTimer -configuration Debug test` → 17 tests, 0 failures
- Manual UI checks remaining: confirm menu-bar countdown updates and popover controls
  on a running macOS build; feel haptics on a physical iOS device (simulator has no
  haptic engine); verify Space/R/S shortcuts don't fight focused steppers in practice.

### 2026-07-26 (pass 2 — focus statistics)

- Added a persistent focus-stats dashboard (presentation + light UserDefaults
  persistence). No timer/sleep/notification behavior changed; the timer core only
  gained one additive completion callback. No new files / no `project.pbxproj` edits —
  new types live at module scope inside `ContentView.swift`.
- Changes:
  - `PomodoroTimerViewModel`: new injected `onFocusSessionCompleted: (Int) -> Void`
    closure (mirrors the existing `presentBreakAttention` DI pattern), fired exactly
    once inside `finish()` with the completed session's `sessionTotalSeconds`. Single
    source of truth — records whether or not any window/menu-bar view is on screen.
  - `FocusStatsStore` (`ContentView.swift`): `@MainActor ObservableObject`, per-day
    JSON aggregate in `UserDefaults` (`focusStats.days.v1`). Exposes todayCount,
    todayFocusMinutes, currentStreak, totalCount, recentDays(_:).
  - `FocusStatsView` (`ContentView.swift`): stat-tile row (今日番茄 / 今日专注 /
    连续打卡 / 累计) + a 7-day mini bar chart, themed with the app's pink→violet
    gradient. Appended to `TimerColumnView` so it appears in both layouts.
  - Store constructed in both app entry points (`TomatoTimerApp.swift`,
    `TomatoTimeriOSApp.swift`), wired to the VM callback, injected into every scene
    (macOS window + menu-bar popover, iOS window).
  - Tests: `testCompletingFocusSessionReportsFocusedDuration` (completion reports the
    planned duration once) and `testResettingRunningSessionDoesNotReportCompletion`
    (reset does not fire the callback). Harness extended to capture callbacks.
- Commands run:
  - `xcodebuild ... -scheme TomatoTimer -configuration Release build` → BUILD SUCCEEDED
  - `xcodebuild ... -scheme TomatoTimer-iOS -configuration Release -destination 'generic/platform=iOS Simulator' build` → BUILD SUCCEEDED
  - `xcodebuild ... -scheme TomatoTimer -configuration Debug test` → 19 tests, 0 failures
- Manual UI checks remaining: confirm the stats card renders and the 7-day bars/streak
  update after completing a real focus session; verify persistence survives an app
  relaunch.

### 2026-07-26 (pass 2b — launch verification + layout fix)

- Ran the macOS Release app and screenshotted it. Found and fixed a real regression
  introduced by the stats card: the regular (non-compact) desktop layout is an HStack
  with NO ScrollView, so appending `FocusStatsView` to the tall timer column clipped
  it against the window's bottom edge.
- Fixes:
  - `ContentView.swift`: wrapped the regular-layout HStack in a `ScrollView(.vertical)`
    with `minHeight: proxy.size.height - verticalPadding*2` so content stays vertically
    centered when it fits and scrolls when it overflows (mirrors the compact branch).
  - `TomatoTimerApp.swift`: bumped `defaultSize` height 720 → 880 so the timer plus the
    full stats card are visible at launch without scrolling.
- Verification:
  - `xcodebuild ... -scheme TomatoTimer -configuration Release build` → BUILD SUCCEEDED
  - Launched Release app; screenshot confirms the 专注战绩 card renders with all four
    tiles (今日番茄 / 今日专注 / 连续打卡 / 累计, all 0 on fresh install) and the timer
    UI is intact. Screenshots saved under the session scratchpad.
- Manual UI checks remaining: complete a real focus session and confirm today/streak/
  total increment and the 7-day bars grow; confirm menu-bar countdown while running.

### 2026-07-26 (pass 3 — iOS Live Activity / Dynamic Island)

- Added a Live Activity (lock screen + Dynamic Island) for the running/paused/break
  countdown. This required a NEW widget-extension target, so the `.xcodeproj` was
  modified — done safely via the Ruby `xcodeproj` gem (1.28.1), NOT by hand. Full
  project backed up first (no git in this repo). macOS is completely unaffected
  (all ActivityKit code is `#if os(iOS)` and the shared attributes file is not a
  member of the macOS target).
- New target: `TomatoTimerWidgetExtension` (app-extension, iOS 17, Swift 6),
  bundle id `com.kai.TomatoTimer.ios.widget`, embedded into the iOS app via an
  "Embed Foundation Extensions" copy-files phase + target dependency.
- New files:
  - `TomatoTimer/PomodoroActivityAttributes.swift` — shared ActivityAttributes
    (member of iOS app + widget targets only).
  - `TomatoTimer/LiveActivityController.swift` — iOS-only `sync/end` async API that
    starts/updates/ends `Activity<PomodoroActivityAttributes>` (no App Group needed;
    the app drives content directly).
  - `TomatoTimerWidget/TomatoTimerWidgetBundle.swift`, `PomodoroLiveActivity.swift`,
    `Info.plist` (widget target). Dynamic Island compact/expanded/minimal + a lock
    screen card; running phases self-count via `Text(timerInterval:)`, paused shows a
    frozen clock.
  - Script kept at scratchpad `add_widget.rb`.
- Wiring (additive, no timer behavior change):
  - `PomodoroTimerViewModel`: read-only `liveActivityEndDate` + `liveActivitySnapshot`
    getters and a plain `Sendable` `LiveActivitySnapshot` struct.
  - `ContentView` (iOS `#if`): `onChange(of: state)` and `onChange(of:
    liveActivityEndDate)` push the snapshot to `LiveActivityController`.
  - iOS app target: `INFOPLIST_KEY_NSSupportsLiveActivities = YES`.
- Verification:
  - `xcodebuild ... -scheme TomatoTimer-iOS ... build` (Debug + Release simulator) → BUILD SUCCEEDED
  - `xcodebuild ... -scheme TomatoTimer -configuration Release build` (macOS) → BUILD SUCCEEDED
  - `xcodebuild ... -scheme TomatoTimer -configuration Debug test` → 19 tests, 0 failures
  - Structural: `.appex` embedded under `TomatoTimer.app/PlugIns/`; app plist
    `NSSupportsLiveActivities = true`; widget `NSExtensionPointIdentifier =
    com.apple.widgetkit-extension`; widget id correctly prefixes the host app id.
  - RUNTIME on iPhone 17 Pro simulator: launched with a temporary `AUTO_START_DEMO`
    env hook, backgrounded the app, and captured the Dynamic Island showing the live
    countdown (flame icon + self-counting time). The temporary hook was reverted and
    the iOS Release build re-verified clean. Screenshots in the session scratchpad.
- Manual UI checks remaining: long-press the Dynamic Island to confirm the expanded
  layout + lock-screen card on a device/simulator; confirm pause shows the frozen
  clock and the activity ends on reset/idle.

### 2026-07-26 (pass 4 — real-bug fixes B1/B2/B3 from the audit)

- Fixed three confirmed defects surfaced by the multi-agent audit. Timer-completion
  and audio-session semantics are touched but no display-sleep/notification behavior
  changed.
- B1 — countdown adjustment desynced `sessionTotalSeconds`
  (`PomodoroTimerViewModel.swift` adjustCountdown): adding time pushed remaining past
  the session total, making `progress` clamp to 0 (ring empties) and the milestone
  `elapsed = total - remaining` go negative. Fix: grow
  `sessionTotalSeconds = max(sessionTotalSeconds, adjustedRemaining)` on adjust.
- B2 — stats over-reported focus time on manual early finish
  (`PomodoroTimerViewModel.swift` finish/adjustCountdown): driving the countdown to
  zero recorded the full *planned* duration. Fix: `finish` now takes
  `completedFocusSecondsOverride`; the manual-zero path records actual elapsed
  (`total - remaining`), while natural completion (incl. background expiry) still
  records the full planned duration.
- B3 — background audio ducked for the whole app lifetime
  (`SpeechNotifier.swift`): the AVAudioSession was `setActive(true)` once at init with
  `.duckOthers` and never deactivated, permanently lowering the user's music. Fix:
  set category only at init; `setActive(true)` right before playback and
  `setActive(false, .notifyOthersOnDeactivation)` when the queue drains / on stop, so
  ducking lasts only while a clip plays. (iOS-only; `#if os(iOS)`.)
- B4 — investigated and dismissed as a false alarm: milestone minutes are always a
  multiple of 5, so the `.skip` branch is unreachable for real callers and long
  sessions already fall back to TTS via `audioResolution`. No change.
- Tests: replaced the now-outdated `testCompletingFocusSessionReportsFocusedDuration`
  (it asserted the B2 bug) with `testEarlyFinishRecordsElapsedFocusNotFullDuration`,
  and added `testIncreasingCountdownGrowsSessionTotalToKeepProgressValid` for B1.
- Verification:
  - macOS Release build → BUILD SUCCEEDED
  - iOS Release (app + widget) build → BUILD SUCCEEDED
  - `xcodebuild ... test` → 20 tests, 0 failures
- Manual UI checks remaining: on iOS, play music then run a focus session and confirm
  the music only ducks during a voice clip and returns to full volume afterward; watch
  the ring while using +1min mid-session to confirm it no longer snaps empty.

### 2026-07-26 (pass 5 — shared palette + settings groundwork)

- #2 Shared `TimerPalette` (new `TomatoTimer/TimerPalette.swift`, added to both app
  targets via the Ruby `xcodeproj` gem; not the widget). Centralizes the focus/break/
  paused/idle colours and gradients that were previously redefined inline in
  `TimerProgressRing.swift`, `TimerFaceLabels.swift`, and `ContentView.swift`
  (FocusStatsView). Values copied verbatim — zero visual change (verified by launch
  screenshot); this is the foundation for later theming.
- #3 (partial, the safe parts):
  - Remember last-used duration (`PomodoroTimerViewModel.swift`): the chosen duration
    now persists to `UserDefaults` ("selectedTotalSeconds") in `enqueueSelectedDuration`
    and is restored in `init`, so the app no longer resets to 25:00 every launch.
  - Speech mute (`SpeechNotifier.swift` + `TimerVoicePicker.swift`): a persisted
    `@AppStorage("speechMuted")` toggle (speaker button next to the voice picker) gates
    `speak` and `playSelfIntro`; completion handlers still fire when muted so the avatar
    flow is unaffected. The voice picker dims/disables while muted.
  - Deferred: configurable break duration — it ripples into the notification/speech copy
    (hardcoded "五分钟"), which is AGENTS.md's sensitive zone; will do as a focused step.
- Verification:
  - macOS Release + iOS Release (app + widget) builds → BUILD SUCCEEDED
  - `xcodebuild ... test` → 20 tests, 0 failures
  - Launch screenshot confirms the palette is visually unchanged and the mute toggle
    renders next to the voice picker.
- Manual UI checks remaining: toggle mute and confirm no voice plays during a session;
  change the duration, relaunch, and confirm it restores instead of resetting to 25:00.

### 2026-07-26 (pass 6 — configurable break duration + Settings surface)

- Made the break length user-configurable (the sensitive item — it drives the
  notification and speech copy). No screen-sleep behavior changed.
- `PomodoroTimerViewModel.swift`:
  - `breakTotalSeconds` is now a stored `var` restored from `UserDefaults`
    ("breakTotalSeconds", default 5 min). New API: `breakMinutes`,
    `setBreakMinutes(_:)` (idle-only, clamped 1...60, persists), `availableBreakMinutes`.
  - `breakFinishedMessage` derives the "已休息…,该继续了" copy from the configured
    length; the 5-minute case keeps the exact wording of the bundled "resume" voice
    clip, other lengths use synthesized speech.
  - **Injected `UserDefaults`** into the VM (`userDefaults:` init param); converted the
    saved-duration/break helpers to instance methods and routed all reads/writes
    through it. This isolates tests from `UserDefaults.standard` (and fixes a latent
    cross-test leak the new persistence would otherwise cause).
- `TimerNotificationScheduler.swift`: `scheduleBreakFinished(after:body:)` now takes the
  body so the "五分钟" string is no longer hardcoded; the VM passes `breakFinishedMessage`.
- New `SettingsView.swift` (added to both app targets via the `xcodeproj` gem): a `Form`
  with a break-duration stepper (disabled while a timer runs) and a mute toggle.
  - macOS: a `Settings { }` scene (⌘,).
  - iOS: a gear button in `ContentView` presenting `SettingsView` in a sheet.
- Tests: `testConfigurableBreakDurationDrivesSnapshotAndCopy` (break length flows into
  the snapshot + notification body) and `testBreakDurationCannotBeChangedWhileRunning`.
  Mock scheduler updated for the new signature and now records bodies.
- Verification:
  - macOS Release + iOS Release (app + widget) builds → BUILD SUCCEEDED
  - `xcodebuild ... test` → 22 tests, 0 failures
- Manual UI checks remaining: open Settings (⌘, on macOS / gear on iOS), change the
  break length, run a focus session, and confirm the break countdown, the spoken
  "已休息…" line, and the "休息结束" notification all reflect the new length; confirm
  the stepper is disabled mid-session.

### 2026-07-26 (pass 7 — iOS platform parity: B5/B6/B7)

- B6 — iOS screen now stays awake during focus. `DisplaySleepAssertion` gained an
  `#elseif os(iOS)` branch toggling `UIApplication.shared.isIdleTimerDisabled` in
  acquire/release (previously macOS-only, a no-op on iOS).
- B7 — iOS foreground notifications now show. `TimerNotificationScheduler` installs a
  `UNUserNotificationCenterDelegate` (`ForegroundNotificationPresenter`) whose
  `willPresent` returns `[.banner, .sound, .list]`, so work/break-finished alerts appear
  even with the app foregrounded (iOS suppresses them by default).
- B5 — timer state now survives app termination.
  - New `TimerRestorationState` (Codable) + pure `TimerRestorationOutcome.resolve(_:now:)`
    decision function (unit-tested deterministically).
  - `PomodoroTimerViewModel` persists the live state to the injected `UserDefaults`
    ("timerRestorationState.v1") at every transition (start/pause/resume/reset/adjust/
    finish/finishBreak/background) and restores it in `init` via `applyRestorationIfNeeded`.
  - Conservative policy: only sessions still active (endDate/breakEndDate in the future,
    or paused) are restored — re-arming endDate, sleep assertion, notifications, and
    ticking. Sessions that expired while the app was dead resolve to idle (their
    scheduled notification already alerted the user); no speech/window-attention is
    replayed on launch.
- Tests (26 total, +4): running-restore, expired-drop, break/paused/nil resolution, and
  a VM integration test that restores a running session from seeded defaults (asserts
  state, remaining, and that the sleep assertion was acquired).
- Verification:
  - macOS Release + iOS Release (app + widget) builds → BUILD SUCCEEDED
  - `xcodebuild ... test` → 26 tests, 0 failures
- Manual UI checks remaining: on a device/simulator, start a focus session, force-quit
  the app, relaunch, and confirm the countdown resumes in sync with the pending
  notification; confirm the iOS screen no longer dims mid-focus and a foreground
  break-finished notification shows a banner.

### 2026-07-26 (pass 8 — testability + coverage for stats & formatting)

- Made `FocusStatsStore` deterministically testable by injecting a clock
  (`now: () -> Date = { Date() }`, `ContentView.swift`); replaced every direct `Date()`
  in record/todayCount/todayFocusMinutes/currentStreak/recentDays with `now()`. It
  already accepted an injected `UserDefaults`. No behavior change (defaults preserved).
- Added coverage (all in `PomodoroTimerViewModelTests.swift`, no new files):
  - `FocusStatsStoreTests` (8): record accumulation, non-positive guard, consecutive-day
    streak, streak break on gap, midnight rollover (today resets, total persists),
    recentDays gap-fill + ordering, corrupt-JSON fallback to empty, cross-instance
    persistence.
  - `DurationUnitFormatterTests` (2): unit names + accessibility value.
  - `TimerFormattingTests` (2): `remainingTimeText` minutes-only ("25:00") and
    hours ("01:05:03"). The second test caught a wrong initial expectation (hours are
    zero-padded) — fixed to match the real format.
- Suite grew 26 → 38 tests.
- Verification:
  - macOS Release + iOS Release (app + widget) builds → BUILD SUCCEEDED
  - `xcodebuild ... test` → 38 tests, 0 failures

### 2026-07-26 (pass 9 — long-break cycle + auto-start next focus, opt-in)

- Added two classic-Pomodoro options, both OFF by default so default behavior is
  unchanged (satisfies AGENTS.md). Touches finish()/finishBreak() — the sensitive
  break/notification path — verified by build + tests.
- `PomodoroTimerViewModel`:
  - New defaults-backed reads: `autoStartNextFocusEnabled`, `longBreakInterval`
    (0 = disabled), `longBreakSeconds`, and a persisted `completedFocusCount`. Public
    static keys (`autoStartDefaultsKey`, `longBreakIntervalDefaultsKey`,
    `longBreakMinutesDefaultsKey`) so the UI binds to the same keys the VM reads.
  - `finish()`: increments the cycle count and uses a long break every N completions
    (`effectiveBreakSeconds`), threading it through breakEndsAt / snapshot / the
    break-finished notification.
  - `breakFinishedMessage` now derives from the *active* break length
    (`currentSnapshot.breakTotalSeconds`), so long-break announcements/notifications
    read correctly.
  - `finishBreak()`: on natural completion, if auto-start is enabled it starts the next
    focus (skipping the "已休息…" line so it flows into "加油…"). Manual skip/reset never
    auto-start.
- `SettingsView`: new "休息节奏" section — auto-start toggle, long-break interval stepper
  (0 = 关闭), and a long-break-length stepper shown when the interval > 0. Bound via
  `@AppStorage` to the VM's keys.
- Tests (41 total, +3): `testLongBreakEveryNSessions` (2nd of every-2 completions gets a
  15-min break), `testBreakStaysNormalWhenLongBreakDisabled` (default path unchanged),
  `testManualSkipDoesNotAutoStartEvenWhenEnabled` (safety: skip never auto-starts).
- Verification:
  - macOS Release + iOS Release (app + widget) builds → BUILD SUCCEEDED
  - `xcodebuild ... test` → 41 tests, 0 failures (existing 5-min-break tests still pass,
    confirming the opt-in defaults don't change behavior)
- Manual UI checks remaining: enable auto-start and let a break run out to confirm the
  next focus begins automatically; set a long-break interval and confirm every Nth break
  is longer and its notification/speech reflect the longer length.

### 2026-07-26 (pass 10 — avatar image downsampling)

- Avatars are 1254×1254 PNGs (~6 MB each when decoded at full resolution). The loader
  previously cached the full-size decoded bitmap regardless of how small it was drawn.
- `AvatarImageLoader` now downsamples via ImageIO (`CGImageSourceCreateThumbnailAtIndex`
  with `ShouldCacheImmediately`) to a `maxPixelSize`, never upscaling past the source
  (reads `kCGImagePropertyPixelWidth/Height` to cap). Added `NSCache` limits
  (countLimit 8, totalCostLimit 32 MB) and a size-bucketed cache key.
- `DigitalAvatarFaceView` wraps the image in a `GeometryReader` and passes
  `max(width,height) * displayScale`, quantized up to 128 px buckets, as the target —
  so the iPhone-compact avatar (~170 pt @3x ≈ 510 px → 512-px thumbnail, ~1 MB) no
  longer keeps a ~6 MB full-res bitmap resident (~80% less). macOS at large sizes still
  gets full resolution (target ≥ source), so there's no quality regression.
- Verification:
  - macOS Release + iOS Release (app + widget) builds → BUILD SUCCEEDED
  - `xcodebuild ... test` → 41 tests, 0 failures
  - Launched both: macOS avatar renders full and crisp (screenshot); iOS app runs.
- Manual UI check remaining: eyeball the iPhone avatar at a few Dynamic-Type/orientation
  sizes to confirm the downsampled thumbnail stays sharp.

### 2026-07-26 (pass 11 — SwiftLint + CI gate)

Tooling pass, no behavior change intended.

- Installed SwiftLint 0.65.0 (`brew install swiftlint`) and added `.swiftlint.yml`
  covering `TomatoTimer`, `TomatoTimerTests`, `TomatoTimerWidget`.
  - Disabled rules that fight idiomatic SwiftUI: `type_body_length`,
    `function_body_length`, `cyclomatic_complexity`,
    `multiple_closures_with_trailing_closure`, `todo`.
  - Disabled `empty_count`: `FocusDayStat.count` is a Codable session tally, not a
    collection, so the rule only ever fired as a false positive. Renaming the property
    would have changed the persisted JSON key for a purely cosmetic gain.
  - Opted into ~35 correctness/consistency rules (`first_where`, `empty_string`,
    `redundant_type_annotation`, `modifier_order`, `unowned_variable_capture`, …).
  - `line_length` warn 120 / error 200; `file_length` warn 600.
- Fixed the 22 violations the first run reported:
  - `PomodoroTimerViewModel.swift`: `completedFocusCount % longBreakInterval == 0`
    → `.isMultiple(of:)` (long-break cadence; covered by existing tests).
  - `PomodoroTimerViewModelTests.swift`: dropped a `try!` — test is now `throws`.
  - `TimerActionsView.swift`: the 重置 button was byte-identical in all four timer
    states; extracted it to a `resetButton` property. `.idle` still applies
    `.disabled(true)`. Removes the duplication and 4 line-length violations at once.
  - `SpeechNotifier.swift`, `TimerNotificationScheduler.swift`, `ContentView.swift`:
    wrapped 13 long lines (log strings, `VoiceChoice` call sites, an accessibility
    label). Mechanical only — the fallback-voice pitch/rate/volume values are
    unchanged.
  - `ContentView.swift`: stripped leading tabs from a block that mixed tabs+spaces.
- Added `Scripts/lint.sh` and `Scripts/ci.sh` (stages: `lint | macos | ios | test`,
  default all). DerivedData goes to `build/DerivedData`, already gitignored.
- Added `.github/workflows/ci.yml` running the same four stages on push/PR.
- Updated `AGENTS.md` to point at `Scripts/ci.sh` as the verification command.
- Verification:
  - `Scripts/ci.sh` → all four stages pass, exit 0
  - `xcodebuild ... test` (verbose) → 41 tests, 0 failures
  - Launched the Release macOS app: renders correctly, 开始 enabled / 重置 greyed in
    the idle state, avatar unaffected (screenshot).

**Remaining lint warnings (2, deliberate):** `file_length` on
`PomodoroTimerViewModel.swift` (1101) and `PomodoroTimerViewModelTests.swift` (805).
Left in place as an honest pointer at the deferred view-model split rather than
raising the threshold to hide them. `Scripts/ci.sh` fails only on error-severity
violations, so these do not block the gate.

**Not verified:** `.github/workflows/ci.yml` has never run — this directory is not a
git repository and has no remote, so GitHub Actions could not be exercised. The
workflow uses `macos-latest` with the runner's default Xcode (no hardcoded
`Xcode_*.app` path, since those names vary by runner image); local Xcode is 26.6.

### 2026-07-26 (pass 12 — git repository)

- `git init -b main`; single initial commit `5f0af75`, 162 files tracked (4.8 MB).
  Branch is `main` to match `.github/workflows/ci.yml`.
- Extended `.gitignore` with `.claude/settings.local.json` and `.codex/` (local-only
  agent config). Confirmed nothing from `build/` (824 MB), `DerivedData/`, or `.omo/`
  was staged, and grepped the tree for credentials/keys before committing — clean.
- The two avatar PNGs (1.6 MB + 1.2 MB) are committed as normal assets; no LFS.
- Working tree clean, **no remote configured and nothing pushed.**
