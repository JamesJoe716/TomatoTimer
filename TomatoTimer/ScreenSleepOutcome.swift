enum ScreenSleepOutcome: Equatable, Sendable {
    case succeeded
    case failed(String)
}

typealias ScreenSleepCompletion = @MainActor @Sendable (ScreenSleepOutcome) -> Void
