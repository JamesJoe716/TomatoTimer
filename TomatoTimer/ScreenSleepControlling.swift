@MainActor
protocol ScreenSleepControlling: AnyObject {
    @discardableResult
    func sleepDisplay(completion: @escaping ScreenSleepCompletion) -> ScreenSleepRequest
    func wakeDisplay() -> ScreenSleepOutcome
}
