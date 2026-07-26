import Foundation

struct TimerSnapshot: Equatable {
    var state: PomodoroTimerState = .idle
    var selectedTotalSeconds: Int = 25 * 60
    var selectedPresetMinutes: Int? = 25
    var remainingSeconds: TimeInterval = 25 * 60
    var sessionTotalSeconds: TimeInterval = 25 * 60
    var breakRemainingSeconds: TimeInterval = 5 * 60
    var breakTotalSeconds: TimeInterval = 5 * 60
}
