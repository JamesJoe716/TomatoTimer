import XCTest
@testable import TomatoTimer

/// The progress-speech state machine had no direct coverage while it lived inside
/// the view model. Now that it is its own type, these pin down the parts that are
/// easy to break: the re-arming, the milestone de-duplication, and the thresholds.
@MainActor
final class FocusSpeechCoordinatorTests: XCTestCase {
    private let restReminder = "去休息吧,下一个世界首富"
    private let finalMinute = "还有最后一分钟"
    private let twentyFiveMinutes: TimeInterval = 25 * 60

    private func makeCoordinator() -> (FocusSpeechCoordinator, SpeechSpy) {
        let spy = SpeechSpy()
        return (FocusSpeechCoordinator(speechNotifier: spy), spy)
    }

    // MARK: - Rest reminder

    func testRestReminderSpeaksOnceInsideTheFinalFiveSeconds() {
        let (coordinator, spy) = makeCoordinator()

        coordinator.update(remaining: 5, sessionTotalSeconds: twentyFiveMinutes)
        coordinator.update(remaining: 4, sessionTotalSeconds: twentyFiveMinutes)
        coordinator.update(remaining: 3, sessionTotalSeconds: twentyFiveMinutes)

        XCTAssertEqual(spy.spokenTexts, [restReminder])
    }

    func testRestReminderFiresEvenForSessionsTooShortForProgressSpeech() {
        let (coordinator, spy) = makeCoordinator()

        // 60s session is below the 10-minute progress-speech floor, but the closing
        // reminder is checked before that guard.
        coordinator.update(remaining: 4, sessionTotalSeconds: 60)

        XCTAssertEqual(spy.spokenTexts, [restReminder])
    }

    func testRestReminderRearmsAfterTimeIsAddedBack() {
        let (coordinator, spy) = makeCoordinator()

        coordinator.update(remaining: 3, sessionTotalSeconds: twentyFiveMinutes)
        coordinator.update(remaining: 120, sessionTotalSeconds: twentyFiveMinutes)
        coordinator.update(remaining: 3, sessionTotalSeconds: twentyFiveMinutes)

        XCTAssertEqual(spy.spokenTexts.filter { $0 == restReminder }.count, 2)
    }

    func testAnnounceRestReminderIfNeededSpeaksOnlyOnce() {
        let (coordinator, spy) = makeCoordinator()

        coordinator.announceRestReminderIfNeeded()
        coordinator.announceRestReminderIfNeeded()

        XCTAssertEqual(spy.spokenTexts, [restReminder])
    }

    // MARK: - Final minute

    func testFinalMinuteSpeaksOnceBetweenSixtyAndFiveSeconds() {
        let (coordinator, spy) = makeCoordinator()

        coordinator.update(remaining: 60, sessionTotalSeconds: twentyFiveMinutes)
        coordinator.update(remaining: 45, sessionTotalSeconds: twentyFiveMinutes)
        coordinator.update(remaining: 30, sessionTotalSeconds: twentyFiveMinutes)

        XCTAssertEqual(spy.spokenTexts, [finalMinute])
    }

    func testFinalMinuteIsSkippedForShortSessions() {
        let (coordinator, spy) = makeCoordinator()

        // 9 minutes is under the 10-minute floor.
        coordinator.update(remaining: 45, sessionTotalSeconds: 9 * 60)

        XCTAssertTrue(spy.spokenTexts.isEmpty)
    }

    func testNothingIsSpokenInTheGapBetweenSixtyAndSeventyFiveSeconds() {
        let (coordinator, spy) = makeCoordinator()

        coordinator.update(remaining: 70, sessionTotalSeconds: twentyFiveMinutes)

        XCTAssertTrue(spy.spokenTexts.isEmpty)
    }

    // MARK: - Progress milestones

    func testMilestoneAnnouncesElapsedMinutesWithAnEncouragement() {
        let (coordinator, spy) = makeCoordinator()

        coordinator.update(remaining: twentyFiveMinutes - 300, sessionTotalSeconds: twentyFiveMinutes)

        XCTAssertEqual(spy.spokenTexts.count, 2)
        XCTAssertEqual(spy.spokenTexts.first, "你努力了5分钟")
        XCTAssertFalse(spy.spokenTexts[1].isEmpty)
    }

    func testMilestoneIsNotRepeatedOnLaterTicks() {
        let (coordinator, spy) = makeCoordinator()

        coordinator.update(remaining: twentyFiveMinutes - 300, sessionTotalSeconds: twentyFiveMinutes)
        coordinator.update(remaining: twentyFiveMinutes - 310, sessionTotalSeconds: twentyFiveMinutes)
        coordinator.update(remaining: twentyFiveMinutes - 400, sessionTotalSeconds: twentyFiveMinutes)

        XCTAssertEqual(spy.spokenTexts.filter { $0.hasPrefix("你努力了") }, ["你努力了5分钟"])
    }

    func testCrossingTwoMilestonesAtOnceAnnouncesOnlyTheLatest() {
        let (coordinator, spy) = makeCoordinator()

        // Jump straight past both the 5- and 10-minute marks.
        coordinator.update(remaining: twentyFiveMinutes - 600, sessionTotalSeconds: twentyFiveMinutes)

        XCTAssertEqual(spy.spokenTexts.filter { $0.hasPrefix("你努力了") }, ["你努力了10分钟"])
    }

    func testConsecutiveMilestonesUseDifferentEncouragements() {
        let (coordinator, spy) = makeCoordinator()

        coordinator.update(remaining: twentyFiveMinutes - 300, sessionTotalSeconds: twentyFiveMinutes)
        coordinator.update(remaining: twentyFiveMinutes - 600, sessionTotalSeconds: twentyFiveMinutes)

        let encouragements = spy.spokenTexts.filter { !$0.hasPrefix("你努力了") }
        XCTAssertEqual(encouragements.count, 2)
        XCTAssertNotEqual(encouragements[0], encouragements[1])
    }

    func testMilestoneRearmsAfterTheCountdownIsRewoundPastIt() {
        let (coordinator, spy) = makeCoordinator()

        coordinator.update(remaining: twentyFiveMinutes - 300, sessionTotalSeconds: twentyFiveMinutes)
        // Rewind to 4 minutes elapsed, below the 5-minute mark's re-arm window.
        coordinator.update(remaining: twentyFiveMinutes - 240, sessionTotalSeconds: twentyFiveMinutes)
        coordinator.update(remaining: twentyFiveMinutes - 300, sessionTotalSeconds: twentyFiveMinutes)

        XCTAssertEqual(
            spy.spokenTexts.filter { $0.hasPrefix("你努力了") },
            ["你努力了5分钟", "你努力了5分钟"]
        )
    }

    // MARK: - Reset

    func testResetClearsReminderMilestoneAndEncouragementState() {
        let (coordinator, spy) = makeCoordinator()

        coordinator.update(remaining: twentyFiveMinutes - 300, sessionTotalSeconds: twentyFiveMinutes)
        let firstEncouragement = spy.spokenTexts[1]

        coordinator.reset()
        spy.spokenTexts.removeAll()

        coordinator.update(remaining: twentyFiveMinutes - 300, sessionTotalSeconds: twentyFiveMinutes)

        XCTAssertEqual(spy.spokenTexts.first, "你努力了5分钟")
        XCTAssertEqual(spy.spokenTexts[1], firstEncouragement, "rotation should restart from the beginning")
    }
}

private final class SpeechSpy: SpeechNotifying {
    var spokenTexts: [String] = []

    func speak(_ text: String) {
        spokenTexts.append(text)
    }

    func speakRestReminder() {
        speak("去休息吧,下一个世界首富")
    }

    func playSelfIntro(gender: VoiceGender) { }
    func reloadVoicesAndLog() { }
    func runAfterCurrentSpeech(_ handler: @escaping @MainActor @Sendable () -> Void) { handler() }
    func stop(preservingCompletionHandlers: Bool) { }
}
