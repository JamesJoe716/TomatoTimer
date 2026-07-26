import XCTest
@testable import TomatoTimer

/// Covers the derived presentation moved off the view model onto TimerSnapshot.
/// Previously only `remainingTimeText` had any direct assertions.
final class TimerSnapshotPresentationTests: XCTestCase {
    private func snapshot(
        state: PomodoroTimerState = .idle,
        selectedTotal: Int = 1500,
        remaining: TimeInterval = 1500,
        sessionTotal: TimeInterval = 1500,
        breakRemaining: TimeInterval = 300,
        breakTotal: TimeInterval = 300
    ) -> TimerSnapshot {
        var snapshot = TimerSnapshot()
        snapshot.state = state
        snapshot.selectedTotalSeconds = selectedTotal
        snapshot.remainingSeconds = remaining
        snapshot.sessionTotalSeconds = sessionTotal
        snapshot.breakRemainingSeconds = breakRemaining
        snapshot.breakTotalSeconds = breakTotal
        return snapshot
    }

    // MARK: - Capabilities

    func testDurationIsEditableOnlyWhileIdle() {
        XCTAssertTrue(snapshot(state: .idle).canEditDuration)
        XCTAssertFalse(snapshot(state: .running).canEditDuration)
        XCTAssertFalse(snapshot(state: .paused).canEditDuration)
        XCTAssertFalse(snapshot(state: .breaking).canEditDuration)
    }

    func testCannotStartAZeroLengthSession() {
        XCTAssertTrue(snapshot(state: .idle, selectedTotal: 60).canStart)
        XCTAssertFalse(snapshot(state: .idle, selectedTotal: 0).canStart)
    }

    func testCountdownIsAdjustableWhileRunningOrPaused() {
        XCTAssertTrue(snapshot(state: .running).canAdjustCountdown)
        XCTAssertTrue(snapshot(state: .paused).canAdjustCountdown)
        XCTAssertFalse(snapshot(state: .idle).canAdjustCountdown)
        XCTAssertFalse(snapshot(state: .breaking).canAdjustCountdown)
    }

    func testBreakIsSkippableOnlyWhileBreaking() {
        XCTAssertTrue(snapshot(state: .breaking).canSkipBreak)
        XCTAssertFalse(snapshot(state: .running).canSkipBreak)
    }

    // MARK: - Selected duration components

    func testSelectedDurationSplitsIntoHoursMinutesSeconds() {
        let value = snapshot(selectedTotal: 1 * 3600 + 5 * 60 + 3)

        XCTAssertEqual(value.selectedHours, 1)
        XCTAssertEqual(value.selectedMinutesComponent, 5)
        XCTAssertEqual(value.selectedSecondsComponent, 3)
    }

    // MARK: - Remaining time text

    func testRemainingTimeUsesMinutesAndSecondsBelowAnHour() {
        XCTAssertEqual(snapshot(remaining: 1500).remainingTimeText, "25:00")
    }

    func testRemainingTimeShowsHoursOnceTheSessionIsAnHourOrMore() {
        let value = snapshot(selectedTotal: 3903, remaining: 3903, sessionTotal: 3903)

        XCTAssertEqual(value.remainingTimeText, "01:05:03")
    }

    func testRemainingTimeRoundsUpSoItNeverReadsZeroWhileTimeRemains() {
        XCTAssertEqual(snapshot(remaining: 0.2).remainingTimeText, "00:01")
    }

    func testBreakingShowsTheBreakCountdownWithoutHours() {
        let value = snapshot(state: .breaking, remaining: 4000, breakRemaining: 90)

        XCTAssertEqual(value.remainingTimeText, "01:30")
    }

    // MARK: - Selected duration text

    func testSelectedDurationTextDescribesTheFocusLength() {
        XCTAssertEqual(snapshot(selectedTotal: 1500).selectedDurationText, "25分 00秒")
        XCTAssertEqual(snapshot(selectedTotal: 3903).selectedDurationText, "1小时 05分 03秒")
        XCTAssertEqual(snapshot(selectedTotal: 30).selectedDurationText, "30秒")
    }

    func testSelectedDurationTextSwitchesToTheBreakLengthWhileBreaking() {
        let value = snapshot(state: .breaking, breakTotal: 600)

        XCTAssertEqual(value.selectedDurationText, "休息 10分 00秒")
    }

    // MARK: - Status

    func testStatusTextMatchesEachState() {
        XCTAssertEqual(snapshot(state: .idle).statusText, "未开始")
        XCTAssertEqual(snapshot(state: .running).statusText, "进行中")
        XCTAssertEqual(snapshot(state: .paused).statusText, "已暂停")
        XCTAssertEqual(snapshot(state: .breaking).statusText, "休息中")
    }

    // MARK: - Progress

    func testProgressTracksElapsedFractionOfTheSession() {
        let value = snapshot(state: .running, remaining: 1125, sessionTotal: 1500)

        XCTAssertEqual(value.progress, 0.25, accuracy: 0.0001)
    }

    func testProgressUsesTheBreakWhileBreaking() {
        let value = snapshot(state: .breaking, remaining: 0, sessionTotal: 1500, breakRemaining: 75, breakTotal: 300)

        XCTAssertEqual(value.progress, 0.75, accuracy: 0.0001)
    }

    func testProgressIsZeroRatherThanNaNWhenTotalsAreZero() {
        XCTAssertEqual(snapshot(state: .running, remaining: 0, sessionTotal: 0).progress, 0)
        XCTAssertEqual(snapshot(state: .breaking, breakRemaining: 0, breakTotal: 0).progress, 0)
    }

    func testProgressClampsWhenRemainingExceedsTheTotal() {
        // Adding time can push remaining past the original session total.
        let value = snapshot(state: .running, remaining: 2000, sessionTotal: 1500)

        XCTAssertEqual(value.progress, 0)
    }

    // MARK: - Break finished message

    func testFiveMinuteBreakKeepsTheBundledClipWording() {
        XCTAssertEqual(snapshot(breakTotal: 300).breakFinishedMessage, "已休息五分钟,该继续了")
    }

    func testOtherBreakLengthsAreDescribedInMinutes() {
        XCTAssertEqual(snapshot(breakTotal: 900).breakFinishedMessage, "已休息15分钟,该继续了")
    }

    func testBreakLengthWithLeftoverSecondsIncludesThem() {
        XCTAssertEqual(snapshot(breakTotal: 330).breakFinishedMessage, "已休息5分30秒,该继续了")
    }
}
