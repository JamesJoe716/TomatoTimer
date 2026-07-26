import Foundation

/// Persisted snapshot of the live timer, used to survive app termination.
struct TimerRestorationState: Codable, Equatable {
    var stateID: String
    var endDate: Date?
    var breakEndDate: Date?
    var remainingSeconds: Double
    var sessionTotalSeconds: Double
    var breakTotalSeconds: Double
}

/// What (if anything) to restore on launch. Pure/deterministic given `now`, so it
/// can be unit-tested without a running clock.
enum TimerRestorationOutcome: Equatable {
    case none
    case running(endDate: Date, sessionTotalSeconds: Double)
    case paused(remainingSeconds: Double, sessionTotalSeconds: Double)
    case breaking(breakEndDate: Date, breakTotalSeconds: Double)

    static func resolve(_ record: TimerRestorationState?, now: Date) -> TimerRestorationOutcome {
        guard let record else { return .none }
        switch record.stateID {
        case "running":
            guard let end = record.endDate, end > now else { return .none }
            return .running(endDate: end, sessionTotalSeconds: record.sessionTotalSeconds)
        case "paused":
            guard record.remainingSeconds > 0 else { return .none }
            return .paused(remainingSeconds: record.remainingSeconds, sessionTotalSeconds: record.sessionTotalSeconds)
        case "breaking":
            guard let end = record.breakEndDate, end > now else { return .none }
            return .breaking(breakEndDate: end, breakTotalSeconds: record.breakTotalSeconds)
        default:
            return .none
        }
    }
}
