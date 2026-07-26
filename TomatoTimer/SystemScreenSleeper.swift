@MainActor
final class SystemScreenSleeper: ScreenSleepControlling {
    @discardableResult
    func sleepDisplay(completion: @escaping ScreenSleepCompletion) -> ScreenSleepRequest {
        ScreenSleeper.sleepDisplay(completion: completion)
    }

    func wakeDisplay() -> ScreenSleepOutcome {
        ScreenSleeper.wakeDisplay()
    }
}
