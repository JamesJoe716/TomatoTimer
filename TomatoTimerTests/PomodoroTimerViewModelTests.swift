import XCTest
@testable import TomatoTimer

@MainActor
final class PomodoroTimerViewModelTests: XCTestCase {
    func testPausedCountdownAdjustedToZeroStartsBreakImmediately() {
        let harness = TimerHarness()
        let timer = harness.makeTimer()

        timer.start()
        timer.pause()
        timer.decreaseCountdown(by: 24 * 60 * 60)

        XCTAssertEqual(timer.state, .breaking)
        XCTAssertEqual(timer.snapshot.remainingSeconds, 0)
        XCTAssertEqual(timer.snapshot.breakRemainingSeconds, 5 * 60, accuracy: 0.5)
        XCTAssertEqual(harness.sleepAssertion.releaseCount, 1)
        #if os(macOS)
        XCTAssertEqual(harness.screenSleeper.sleepRequests, 1)
        #else
        XCTAssertEqual(harness.screenSleeper.sleepRequests, 0)
        #endif
        XCTAssertTrue(harness.speechNotifier.spokenTexts.contains("去休息吧,下一个世界首富"))
    }

    func testEarlyFinishRecordsElapsedFocusNotFullDuration() {
        let harness = TimerHarness()
        let timer = harness.makeTimer()

        timer.selectPreset(minutes: 25) // 1500s planned
        timer.start()
        timer.pause()
        timer.decreaseCountdown(by: 5 * 60)       // 5 minutes of focus consumed
        timer.decreaseCountdown(by: 24 * 60 * 60) // drive to zero -> early finish

        XCTAssertEqual(timer.state, .breaking)
        XCTAssertEqual(harness.recordedFocusSeconds.count, 1)
        let recorded = harness.recordedFocusSeconds.first ?? -1
        // Actual focused time (~5 min), not the full 25 min planned.
        XCTAssertLessThanOrEqual(abs(recorded - 5 * 60), 2)
    }

    func testConfigurableBreakDurationDrivesSnapshotAndCopy() {
        let harness = TimerHarness()
        let timer = harness.makeTimer()

        timer.setBreakMinutes(10)
        XCTAssertEqual(timer.breakMinutes, 10)

        timer.selectPreset(minutes: 25)
        timer.start()
        timer.pause()
        timer.decreaseCountdown(by: 24 * 60 * 60) // enter break

        XCTAssertEqual(timer.state, .breaking)
        XCTAssertEqual(timer.snapshot.breakTotalSeconds, 10 * 60, accuracy: 0.5)
        XCTAssertEqual(timer.snapshot.breakRemainingSeconds, 10 * 60, accuracy: 0.5)
        XCTAssertTrue(harness.notificationScheduler.breakFinishedBodies.contains { $0.contains("10分钟") })
    }

    private func completeOneFocus(_ timer: PomodoroTimerViewModel) {
        timer.selectPreset(minutes: 25)
        timer.start()
        timer.pause()
        timer.decreaseCountdown(by: 24 * 60 * 60) // drive to zero -> break
    }

    func testLongBreakEveryNSessions() {
        let harness = TimerHarness()
        harness.defaults.set(2, forKey: "longBreakInterval")
        harness.defaults.set(15, forKey: "longBreakMinutes")
        let timer = harness.makeTimer()

        completeOneFocus(timer) // 1st completion -> normal break
        XCTAssertEqual(timer.snapshot.breakTotalSeconds, 5 * 60, accuracy: 0.5)
        timer.skipBreak()

        completeOneFocus(timer) // 2nd completion -> long break
        XCTAssertEqual(timer.snapshot.breakTotalSeconds, 15 * 60, accuracy: 0.5)
    }

    func testBreakStaysNormalWhenLongBreakDisabled() {
        let harness = TimerHarness()
        let timer = harness.makeTimer()

        completeOneFocus(timer)
        XCTAssertEqual(timer.snapshot.breakTotalSeconds, 5 * 60, accuracy: 0.5)
        timer.skipBreak()

        completeOneFocus(timer)
        XCTAssertEqual(timer.snapshot.breakTotalSeconds, 5 * 60, accuracy: 0.5)
    }

    func testManualSkipDoesNotAutoStartEvenWhenEnabled() {
        let harness = TimerHarness()
        harness.defaults.set(true, forKey: "autoStartNextFocus")
        let timer = harness.makeTimer()

        completeOneFocus(timer)
        XCTAssertEqual(timer.state, .breaking)

        timer.skipBreak()
        XCTAssertEqual(timer.state, .idle) // auto-start only on natural completion
    }

    func testBreakDurationCannotBeChangedWhileRunning() {
        let harness = TimerHarness()
        let timer = harness.makeTimer()

        timer.start()
        timer.setBreakMinutes(15)

        XCTAssertEqual(timer.breakMinutes, 5) // unchanged; editing only allowed while idle
    }

    func testRestorationKeepsActiveRunningSession() {
        let now = Date(timeIntervalSinceReferenceDate: 1000)
        let record = TimerRestorationState(
            stateID: "running", endDate: now.addingTimeInterval(300), breakEndDate: nil,
            remainingSeconds: 300, sessionTotalSeconds: 1500, breakTotalSeconds: 300
        )
        XCTAssertEqual(
            TimerRestorationOutcome.resolve(record, now: now),
            .running(endDate: now.addingTimeInterval(300), sessionTotalSeconds: 1500)
        )
    }

    func testRestorationDropsExpiredRunningSession() {
        let now = Date(timeIntervalSinceReferenceDate: 1000)
        let record = TimerRestorationState(
            stateID: "running", endDate: now.addingTimeInterval(-5), breakEndDate: nil,
            remainingSeconds: 0, sessionTotalSeconds: 1500, breakTotalSeconds: 300
        )
        XCTAssertEqual(TimerRestorationOutcome.resolve(record, now: now), .none)
    }

    func testRestorationKeepsActiveBreakAndPaused() {
        let now = Date(timeIntervalSinceReferenceDate: 1000)
        let breakRecord = TimerRestorationState(
            stateID: "breaking", endDate: nil, breakEndDate: now.addingTimeInterval(120),
            remainingSeconds: 0, sessionTotalSeconds: 1500, breakTotalSeconds: 300
        )
        XCTAssertEqual(
            TimerRestorationOutcome.resolve(breakRecord, now: now),
            .breaking(breakEndDate: now.addingTimeInterval(120), breakTotalSeconds: 300)
        )

        let pausedRecord = TimerRestorationState(
            stateID: "paused", endDate: nil, breakEndDate: nil,
            remainingSeconds: 600, sessionTotalSeconds: 1500, breakTotalSeconds: 300
        )
        XCTAssertEqual(
            TimerRestorationOutcome.resolve(pausedRecord, now: now),
            .paused(remainingSeconds: 600, sessionTotalSeconds: 1500)
        )

        XCTAssertEqual(TimerRestorationOutcome.resolve(nil, now: now), .none)
    }

    func testViewModelRestoresRunningSessionFromDefaults() throws {
        let harness = TimerHarness()
        let record = TimerRestorationState(
            stateID: "running", endDate: Date().addingTimeInterval(300), breakEndDate: nil,
            remainingSeconds: 300, sessionTotalSeconds: 1500, breakTotalSeconds: 300
        )
        let encoded = try JSONEncoder().encode(record)
        harness.defaults.set(encoded, forKey: "timerRestorationState.v1")

        let timer = harness.makeTimer()

        XCTAssertEqual(timer.state, .running)
        XCTAssertEqual(timer.snapshot.sessionTotalSeconds, 1500, accuracy: 1)
        XCTAssertGreaterThan(timer.snapshot.remainingSeconds, 0)
        XCTAssertEqual(harness.sleepAssertion.acquireCount, 1)
    }

    func testIncreasingCountdownGrowsSessionTotalToKeepProgressValid() {
        let harness = TimerHarness()
        let timer = harness.makeTimer()

        timer.selectPreset(minutes: 5) // 300s
        timer.start()
        timer.increaseCountdown(by: 10 * 60) // remaining now ~900 > original 300

        XCTAssertGreaterThanOrEqual(timer.snapshot.sessionTotalSeconds, timer.snapshot.remainingSeconds)
        XCTAssertGreaterThanOrEqual(timer.progress, 0)
        XCTAssertLessThanOrEqual(timer.progress, 1)
    }

    func testResettingRunningSessionDoesNotReportCompletion() {
        let harness = TimerHarness()
        let timer = harness.makeTimer()

        timer.start()
        timer.reset()

        XCTAssertEqual(timer.state, .idle)
        XCTAssertTrue(harness.recordedFocusSeconds.isEmpty)
    }

    func testResetDuringBreakStopsSpeechAndRestoresSelectedDuration() {
        let harness = TimerHarness()
        let timer = harness.makeTimer()

        timer.start()
        timer.pause()
        timer.decreaseCountdown(by: 24 * 60 * 60)
        timer.reset()

        XCTAssertEqual(timer.state, .idle)
        XCTAssertEqual(timer.snapshot.remainingSeconds, TimeInterval(timer.snapshot.selectedTotalSeconds))
        XCTAssertEqual(harness.speechNotifier.stopCount, 2)
    }

    func testResetBeforeSpeechCompletionDoesNotRequestSleep() {
        let harness = TimerHarness()
        harness.speechNotifier.automaticallyCompletesSpeech = false
        let timer = harness.makeTimer()

        timer.start()
        timer.pause()
        timer.decreaseCountdown(by: 24 * 60 * 60)

        XCTAssertEqual(timer.state, .breaking)
        XCTAssertEqual(harness.screenSleeper.sleepRequests, 0)

        timer.reset()
        harness.speechNotifier.completeSpeech()

        XCTAssertEqual(timer.state, .idle)
        XCTAssertEqual(harness.screenSleeper.sleepRequests, 0)
        XCTAssertNil(timer.systemNoticeText)
    }

    func testSkipBreakBeforeSpeechCompletionDoesNotRequestSleep() {
        let harness = TimerHarness()
        harness.speechNotifier.automaticallyCompletesSpeech = false
        let timer = harness.makeTimer()

        timer.start()
        timer.pause()
        timer.decreaseCountdown(by: 24 * 60 * 60)

        XCTAssertEqual(timer.state, .breaking)
        XCTAssertEqual(harness.screenSleeper.sleepRequests, 0)

        timer.skipBreak()
        harness.speechNotifier.completeSpeech()

        XCTAssertEqual(timer.state, .idle)
        XCTAssertEqual(harness.screenSleeper.sleepRequests, 0)
        XCTAssertNil(timer.systemNoticeText)
    }

    func testSleepFailurePublishesUserVisibleNotice() async {
        let harness = TimerHarness()
        harness.screenSleeper.nextSleepOutcome = .failed("pmset failed")
        let timer = harness.makeTimer()

        timer.start()
        timer.pause()
        timer.decreaseCountdown(by: 24 * 60 * 60)

        #if os(macOS)
        await Task.yield()
        XCTAssertEqual(timer.systemNoticeText, "无法熄灭显示器: pmset failed")

        timer.clearSystemNotice()
        #else
        XCTAssertEqual(harness.screenSleeper.sleepRequests, 0)
        #endif

        XCTAssertNil(timer.systemNoticeText)
    }

    func testResetDuringBreakCancelsSleepRequestAndIgnoresLateCompletion() {
        let harness = TimerHarness()
        harness.screenSleeper.automaticallyCompletesSleep = false
        let timer = harness.makeTimer()

        timer.start()
        timer.pause()
        timer.decreaseCountdown(by: 24 * 60 * 60)

        #if os(macOS)
        let request = harness.screenSleeper.latestSleepRequest
        XCTAssertEqual(harness.screenSleeper.sleepRequests, 1)

        timer.reset()

        XCTAssertEqual(request?.cancelCount, 1)
        XCTAssertEqual(timer.state, .idle)

        harness.screenSleeper.completePendingSleep(with: .failed("late pmset failure"))
        XCTAssertNil(timer.systemNoticeText)
        #else
        XCTAssertEqual(harness.screenSleeper.sleepRequests, 0)
        #endif
    }

    func testSkipBreakCancelsSleepRequestAndIgnoresLateCompletion() {
        let harness = TimerHarness()
        harness.screenSleeper.automaticallyCompletesSleep = false
        let timer = harness.makeTimer()

        timer.start()
        timer.pause()
        timer.decreaseCountdown(by: 24 * 60 * 60)

        #if os(macOS)
        let request = harness.screenSleeper.latestSleepRequest
        XCTAssertEqual(harness.screenSleeper.sleepRequests, 1)

        timer.skipBreak()

        XCTAssertEqual(request?.cancelCount, 1)
        XCTAssertEqual(timer.state, .idle)

        harness.screenSleeper.completePendingSleep(with: .failed("late pmset failure"))
        XCTAssertNil(timer.systemNoticeText)
        #else
        XCTAssertEqual(harness.screenSleeper.sleepRequests, 0)
        #endif
    }

    func testResetDuringBreakClearsSleepFailureNotice() async {
        let harness = TimerHarness()
        harness.screenSleeper.nextSleepOutcome = .failed("pmset failed")
        let timer = harness.makeTimer()

        timer.start()
        timer.pause()
        timer.decreaseCountdown(by: 24 * 60 * 60)

        #if os(macOS)
        await Task.yield()
        XCTAssertEqual(timer.systemNoticeText, "无法熄灭显示器: pmset failed")

        timer.reset()

        XCTAssertEqual(timer.state, .idle)
        XCTAssertNil(timer.systemNoticeText)
        #else
        XCTAssertEqual(harness.screenSleeper.sleepRequests, 0)
        #endif
    }

    func testSkippingBreakClearsSleepFailureNotice() async {
        let harness = TimerHarness()
        harness.screenSleeper.nextSleepOutcome = .failed("pmset failed")
        let timer = harness.makeTimer()

        timer.start()
        timer.pause()
        timer.decreaseCountdown(by: 24 * 60 * 60)

        #if os(macOS)
        await Task.yield()
        XCTAssertEqual(timer.systemNoticeText, "无法熄灭显示器: pmset failed")

        timer.skipBreak()

        XCTAssertNil(timer.systemNoticeText)
        #else
        XCTAssertEqual(harness.screenSleeper.sleepRequests, 0)
        #endif
    }

    func testStartPauseResumeResetBalancesDisplaySleepAssertion() {
        let harness = TimerHarness()
        let timer = harness.makeTimer()

        timer.start()
        XCTAssertEqual(timer.state, .running)
        XCTAssertEqual(harness.sleepAssertion.acquireCount, 1)

        timer.pause()
        XCTAssertEqual(timer.state, .paused)
        XCTAssertEqual(harness.sleepAssertion.releaseCount, 1)

        timer.resume()
        XCTAssertEqual(timer.state, .running)
        XCTAssertEqual(harness.sleepAssertion.acquireCount, 2)

        timer.reset()
        XCTAssertEqual(timer.state, .idle)
        XCTAssertEqual(harness.sleepAssertion.releaseCount, 2)
        XCTAssertEqual(timer.snapshot.remainingSeconds, TimeInterval(timer.snapshot.selectedTotalSeconds))
        XCTAssertNil(timer.systemNoticeText)
    }

    func testStartPauseResumeAndResetMaintainTimerNotifications() {
        let harness = TimerHarness()
        let timer = harness.makeTimer()

        timer.start()
        XCTAssertEqual(harness.notificationScheduler.prepareCount, 1)
        XCTAssertEqual(harness.notificationScheduler.workFinishedSchedules.count, 1)
        XCTAssertEqual(harness.notificationScheduler.breakFinishedSchedules.count, 1)

        timer.pause()
        XCTAssertEqual(harness.notificationScheduler.cancelCount, 1)

        timer.resume()
        XCTAssertEqual(harness.notificationScheduler.prepareCount, 2)
        XCTAssertEqual(harness.notificationScheduler.workFinishedSchedules.count, 2)
        XCTAssertEqual(harness.notificationScheduler.breakFinishedSchedules.count, 2)

        timer.reset()
        XCTAssertEqual(harness.notificationScheduler.cancelCount, 2)
    }

    func testBreakSchedulesBreakFinishedNotificationAndResetCancelsIt() {
        let harness = TimerHarness()
        let timer = harness.makeTimer()

        timer.start()
        timer.pause()
        timer.decreaseCountdown(by: 24 * 60 * 60)

        XCTAssertEqual(timer.state, .breaking)
        XCTAssertEqual(harness.notificationScheduler.breakFinishedSchedules.count, 2)
        XCTAssertEqual(harness.notificationScheduler.breakFinishedSchedules.last ?? 0, 5 * 60, accuracy: 0.5)

        timer.reset()
        XCTAssertEqual(harness.notificationScheduler.cancelCount, 3)
    }

    func testSceneBackgroundRefreshesPendingNotificationSchedule() {
        let harness = TimerHarness()
        let timer = harness.makeTimer()

        timer.start()
        let schedulesAfterStart = harness.notificationScheduler.workFinishedSchedules.count
        let breakSchedulesAfterStart = harness.notificationScheduler.breakFinishedSchedules.count

        timer.handleSceneDidEnterBackground()

        XCTAssertEqual(harness.notificationScheduler.workFinishedSchedules.count, schedulesAfterStart + 1)
        XCTAssertEqual(harness.notificationScheduler.breakFinishedSchedules.count, breakSchedulesAfterStart + 1)
        XCTAssertEqual(
            harness.notificationScheduler.breakFinishedSchedules.last ?? 0,
            (harness.notificationScheduler.workFinishedSchedules.last ?? 0) + 5 * 60,
            accuracy: 0.5
        )
    }

    func testZeroDurationStartRemainsIdle() {
        let harness = TimerHarness()
        let timer = harness.makeTimer()

        timer.setHours(0)
        timer.setMinutesComponent(0)
        timer.setSecondsComponent(0)
        timer.start()

        XCTAssertEqual(timer.state, .idle)
        XCTAssertFalse(timer.canStart)
        XCTAssertEqual(harness.sleepAssertion.acquireCount, 0)
        XCTAssertTrue(harness.speechNotifier.spokenTexts.isEmpty)
    }

    func testDurationEditingIsIgnoredOutsideEditableStates() async {
        let harness = TimerHarness()
        harness.speechNotifier.automaticallyCompletesSpeech = false
        let timer = harness.makeTimer()

        timer.selectPreset(minutes: 15)
        await Task.yield()
        let selectedTotal = timer.snapshot.selectedTotalSeconds

        timer.start()
        timer.selectPreset(minutes: 45)
        timer.setHours(1)
        XCTAssertEqual(timer.snapshot.selectedTotalSeconds, selectedTotal)

        timer.pause()
        timer.setMinutesComponent(5)
        XCTAssertEqual(timer.snapshot.selectedTotalSeconds, selectedTotal)

        timer.decreaseCountdown(by: 24 * 60 * 60)
        XCTAssertEqual(timer.state, .breaking)
        timer.setSecondsComponent(30)
        XCTAssertEqual(timer.snapshot.selectedTotalSeconds, selectedTotal)
    }

    func testCountdownAdjustmentsAreIgnoredWhenNotWorking() {
        let harness = TimerHarness()
        harness.speechNotifier.automaticallyCompletesSpeech = false
        let timer = harness.makeTimer()

        let selectedTotal = timer.snapshot.selectedTotalSeconds
        timer.increaseCountdown(by: 60)
        timer.decreaseCountdown(by: 60)
        XCTAssertEqual(timer.snapshot.remainingSeconds, TimeInterval(selectedTotal))

        timer.start()
        timer.pause()
        timer.decreaseCountdown(by: 24 * 60 * 60)
        XCTAssertEqual(timer.state, .breaking)

        timer.increaseCountdown(by: 60)
        timer.decreaseCountdown(by: 60)
        XCTAssertEqual(timer.snapshot.breakRemainingSeconds, 5 * 60, accuracy: 0.5)
    }
}

@MainActor
private final class TimerHarness {
    let speechNotifier = MockSpeechNotifier()
    let sleepAssertion = MockDisplaySleepAssertion()
    let screenSleeper = MockScreenSleeper()
    let notificationScheduler = MockTimerNotificationScheduler()
    let defaults = UserDefaults(suiteName: "TomatoTimerTests-\(UUID().uuidString)")!
    var recordedFocusSeconds: [Int] = []

    func makeTimer() -> PomodoroTimerViewModel {
        PomodoroTimerViewModel(
            speechNotifier: speechNotifier,
            sleepAssertion: sleepAssertion,
            screenSleeper: screenSleeper,
            notificationScheduler: notificationScheduler,
            userDefaults: defaults,
            onFocusSessionCompleted: { [weak self] seconds in
                self?.recordedFocusSeconds.append(seconds)
            }
        )
    }
}

@MainActor
private final class MockSpeechNotifier: SpeechNotifying {
    var spokenTexts: [String] = []
    var stopCount = 0
    var hasPendingSpeech = false
    var automaticallyCompletesSpeech = true
    private var completionHandlers: [@MainActor @Sendable () -> Void] = []

    func speak(_ text: String) {
        spokenTexts.append(text)
        hasPendingSpeech = true
    }

    func speakRestReminder() {
        speak("去休息吧,下一个世界首富")
    }

    func playSelfIntro(gender: VoiceGender) {
        speak(gender.selfIntroText)
    }

    func reloadVoicesAndLog() { }

    func runAfterCurrentSpeech(_ handler: @escaping @MainActor @Sendable () -> Void) {
        if hasPendingSpeech {
            completionHandlers.append(handler)
            if automaticallyCompletesSpeech {
                completeSpeech()
            }
        } else {
            handler()
        }
    }

    func stop(preservingCompletionHandlers: Bool) {
        stopCount += 1
        hasPendingSpeech = false
        if !preservingCompletionHandlers {
            completionHandlers.removeAll()
        }
        if preservingCompletionHandlers, automaticallyCompletesSpeech {
            completeSpeech()
        }
    }

    func completeSpeech() {
        let handlers = completionHandlers
        completionHandlers.removeAll()
        hasPendingSpeech = false
        handlers.forEach { $0() }
    }
}

@MainActor
private final class MockDisplaySleepAssertion: DisplaySleepControlling {
    var acquireCount = 0
    var releaseCount = 0

    func acquire() {
        acquireCount += 1
    }

    func release() {
        releaseCount += 1
    }
}

@MainActor
private final class MockScreenSleeper: ScreenSleepControlling {
    var sleepRequests = 0
    var wakeRequests = 0
    var nextSleepOutcome = ScreenSleepOutcome.succeeded
    var nextWakeOutcome = ScreenSleepOutcome.succeeded
    var automaticallyCompletesSleep = true
    private(set) var latestSleepRequest: MockScreenSleepRequest?
    private var pendingSleepCompletion: ScreenSleepCompletion?

    @discardableResult
    func sleepDisplay(completion: @escaping ScreenSleepCompletion) -> ScreenSleepRequest {
        sleepRequests += 1
        let request = MockScreenSleepRequest()
        latestSleepRequest = request

        if automaticallyCompletesSleep {
            let outcome = nextSleepOutcome
            Task { @MainActor in
                completion(outcome)
            }
        } else {
            pendingSleepCompletion = completion
        }

        return request
    }

    func wakeDisplay() -> ScreenSleepOutcome {
        wakeRequests += 1
        return nextWakeOutcome
    }

    func completePendingSleep(with outcome: ScreenSleepOutcome? = nil) {
        guard let completion = pendingSleepCompletion else { return }
        pendingSleepCompletion = nil
        completion(outcome ?? nextSleepOutcome)
    }
}

@MainActor
private final class MockScreenSleepRequest: ScreenSleepRequest {
    private(set) var cancelCount = 0

    func cancel() {
        cancelCount += 1
    }
}

@MainActor
private final class MockTimerNotificationScheduler: TimerNotificationControlling {
    var prepareCount = 0
    var cancelCount = 0
    var workFinishedSchedules: [TimeInterval] = []
    var breakFinishedSchedules: [TimeInterval] = []
    var breakFinishedBodies: [String] = []

    func prepareForTimerUse() {
        prepareCount += 1
    }

    func scheduleWorkFinished(after seconds: TimeInterval) {
        workFinishedSchedules.append(seconds)
    }

    func scheduleBreakFinished(after seconds: TimeInterval, body: String) {
        breakFinishedSchedules.append(seconds)
        breakFinishedBodies.append(body)
    }

    func cancelPendingTimerNotifications() {
        cancelCount += 1
    }
}

@MainActor
final class FocusStatsStoreTests: XCTestCase {
    private func makeStore(now: @escaping () -> Date) -> FocusStatsStore {
        FocusStatsStore(defaults: UserDefaults(suiteName: "FocusStatsTests-\(UUID().uuidString)")!, now: now)
    }

    func testRecordAccumulatesTodayCountAndMinutes() {
        let day = Date(timeIntervalSinceReferenceDate: 700_000)
        let store = makeStore(now: { day })

        store.record(focusSeconds: 25 * 60)
        store.record(focusSeconds: 5 * 60)

        XCTAssertEqual(store.todayCount, 2)
        XCTAssertEqual(store.todayFocusMinutes, 30)
        XCTAssertEqual(store.totalCount, 2)
    }

    func testRecordIgnoresNonPositiveSeconds() {
        let store = makeStore(now: { Date(timeIntervalSinceReferenceDate: 700_000) })
        store.record(focusSeconds: 0)
        store.record(focusSeconds: -100)
        XCTAssertEqual(store.totalCount, 0)
    }

    func testStreakCountsConsecutiveDays() {
        var current = Date(timeIntervalSinceReferenceDate: 700_000)
        let store = makeStore(now: { current })

        store.record(focusSeconds: 60)
        current = current.addingTimeInterval(86_400)
        store.record(focusSeconds: 60)
        current = current.addingTimeInterval(86_400)
        store.record(focusSeconds: 60)

        XCTAssertEqual(store.currentStreak, 3)
    }

    func testStreakBreaksWithGap() {
        var current = Date(timeIntervalSinceReferenceDate: 700_000)
        let store = makeStore(now: { current })

        store.record(focusSeconds: 60)
        current = current.addingTimeInterval(2 * 86_400) // skip a day
        store.record(focusSeconds: 60)

        XCTAssertEqual(store.currentStreak, 1)
    }

    func testTodayResetsAfterRolloverButTotalPersists() {
        var current = Date(timeIntervalSinceReferenceDate: 700_000)
        let store = makeStore(now: { current })

        store.record(focusSeconds: 25 * 60)
        XCTAssertEqual(store.todayCount, 1)

        current = current.addingTimeInterval(86_400)
        XCTAssertEqual(store.todayCount, 0)
        XCTAssertEqual(store.totalCount, 1)
    }

    func testRecentDaysFillsGapsAndOrdersOldestToNewest() {
        let current = Date(timeIntervalSinceReferenceDate: 700_000)
        let store = makeStore(now: { current })

        store.record(focusSeconds: 60)
        let week = store.recentDays(7)

        XCTAssertEqual(week.count, 7)
        XCTAssertEqual(week.last?.count, 1)
        XCTAssertEqual(week.dropLast().map(\.count), [0, 0, 0, 0, 0, 0])
    }

    func testCorruptPersistedDataFallsBackToEmpty() {
        let defaults = UserDefaults(suiteName: "FocusStatsTests-corrupt-\(UUID().uuidString)")!
        defaults.set(Data("not json".utf8), forKey: "focusStats.days.v1")

        let store = FocusStatsStore(defaults: defaults, now: { Date() })
        XCTAssertEqual(store.totalCount, 0)
    }

    func testRecordPersistsAcrossStoreInstances() {
        let defaults = UserDefaults(suiteName: "FocusStatsTests-persist-\(UUID().uuidString)")!
        let day = Date(timeIntervalSinceReferenceDate: 700_000)

        let store1 = FocusStatsStore(defaults: defaults, now: { day })
        store1.record(focusSeconds: 25 * 60)

        let store2 = FocusStatsStore(defaults: defaults, now: { day })
        XCTAssertEqual(store2.todayCount, 1)
        XCTAssertEqual(store2.todayFocusMinutes, 25)
    }
}

final class DurationUnitFormatterTests: XCTestCase {
    func testUnitNames() {
        XCTAssertEqual(DurationUnitFormatter.unitName(for: "时"), "小时")
        XCTAssertEqual(DurationUnitFormatter.unitName(for: "分"), "分钟")
        XCTAssertEqual(DurationUnitFormatter.unitName(for: "秒"), "秒钟")
        XCTAssertEqual(DurationUnitFormatter.unitName(for: "X"), "X")
    }

    func testAccessibilityValue() {
        XCTAssertEqual(DurationUnitFormatter.accessibilityValue(title: "分", value: 25), "25分钟")
    }
}

@MainActor
final class TimerFormattingTests: XCTestCase {
    private func makeTimer() -> PomodoroTimerViewModel {
        PomodoroTimerViewModel(
            speechNotifier: MockSpeechNotifier(),
            sleepAssertion: MockDisplaySleepAssertion(),
            screenSleeper: MockScreenSleeper(),
            notificationScheduler: MockTimerNotificationScheduler(),
            userDefaults: UserDefaults(suiteName: "FormatTests-\(UUID().uuidString)")!
        )
    }

    func testRemainingTimeTextMinutesOnly() {
        let timer = makeTimer()
        timer.selectPreset(minutes: 25)
        XCTAssertEqual(timer.remainingTimeText, "25:00")
    }

    func testRemainingTimeTextWithHours() {
        let timer = makeTimer()
        timer.setHours(1)
        timer.setMinutesComponent(5)
        timer.setSecondsComponent(3)
        XCTAssertEqual(timer.remainingTimeText, "01:05:03")
    }
}
