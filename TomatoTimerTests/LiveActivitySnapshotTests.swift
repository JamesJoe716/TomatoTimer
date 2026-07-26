import XCTest
@testable import TomatoTimer

/// Live Activity payload construction, previously inlined in the view model where
/// the paused case's `Date.now` made it awkward to assert on.
final class LiveActivitySnapshotTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func snapshot(
        state: PomodoroTimerState,
        remaining: TimeInterval = 300,
        sessionTotal: TimeInterval = 1500,
        breakRemaining: TimeInterval = 120,
        breakTotal: TimeInterval = 300
    ) -> TimerSnapshot {
        var snapshot = TimerSnapshot()
        snapshot.state = state
        snapshot.remainingSeconds = remaining
        snapshot.sessionTotalSeconds = sessionTotal
        snapshot.breakRemainingSeconds = breakRemaining
        snapshot.breakTotalSeconds = breakTotal
        return snapshot
    }

    func testIdleProducesNoActivity() {
        let result = LiveActivitySnapshot.make(
            snapshot: snapshot(state: .idle), endDate: now, breakEndDate: now, now: now
        )

        XCTAssertNil(result)
    }

    func testRunningSpansTheFullSessionEndingAtTheEndDate() {
        let endDate = now.addingTimeInterval(300)

        let result = LiveActivitySnapshot.make(
            snapshot: snapshot(state: .running), endDate: endDate, breakEndDate: nil, now: now
        )

        XCTAssertEqual(result?.phase, "专注中")
        XCTAssertEqual(result?.isBreak, false)
        XCTAssertEqual(result?.isPaused, false)
        XCTAssertEqual(result?.endDate, endDate)
        // Window starts a full session before the end, not at "now".
        XCTAssertEqual(result?.startDate, endDate.addingTimeInterval(-1500))
        XCTAssertEqual(result?.remainingSeconds, 300)
    }

    func testRunningWithoutAnEndDateProducesNoActivity() {
        let result = LiveActivitySnapshot.make(
            snapshot: snapshot(state: .running), endDate: nil, breakEndDate: nil, now: now
        )

        XCTAssertNil(result)
    }

    func testPausedSynthesisesAWindowAroundNow() {
        let result = LiveActivitySnapshot.make(
            snapshot: snapshot(state: .paused, remaining: 300, sessionTotal: 1500),
            endDate: nil, breakEndDate: nil, now: now
        )

        XCTAssertEqual(result?.phase, "已暂停")
        XCTAssertEqual(result?.isPaused, true)
        // 1500 total - 300 remaining = 1200 elapsed.
        XCTAssertEqual(result?.startDate, now.addingTimeInterval(-1200))
        XCTAssertEqual(result?.endDate, now.addingTimeInterval(300))
        XCTAssertEqual(result?.remainingSeconds, 300)
    }

    func testPausedClampsElapsedWhenRemainingExceedsTheTotal() {
        // Adding time can push remaining past the original total.
        let result = LiveActivitySnapshot.make(
            snapshot: snapshot(state: .paused, remaining: 2000, sessionTotal: 1500),
            endDate: nil, breakEndDate: nil, now: now
        )

        XCTAssertEqual(result?.startDate, now, "elapsed should clamp to 0, never go negative")
    }

    func testBreakingSpansTheBreakEndingAtTheBreakEndDate() {
        let breakEndDate = now.addingTimeInterval(120)

        let result = LiveActivitySnapshot.make(
            snapshot: snapshot(state: .breaking), endDate: nil, breakEndDate: breakEndDate, now: now
        )

        XCTAssertEqual(result?.phase, "休息中")
        XCTAssertEqual(result?.isBreak, true)
        XCTAssertEqual(result?.startDate, breakEndDate.addingTimeInterval(-300))
        XCTAssertEqual(result?.endDate, breakEndDate)
        XCTAssertEqual(result?.remainingSeconds, 120)
    }

    func testBreakingWithoutABreakEndDateProducesNoActivity() {
        let result = LiveActivitySnapshot.make(
            snapshot: snapshot(state: .breaking), endDate: now, breakEndDate: nil, now: now
        )

        XCTAssertNil(result)
    }
}
