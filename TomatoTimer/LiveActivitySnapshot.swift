import Foundation

/// Plain, platform-agnostic payload the view layer forwards to the Live Activity.
/// Kept free of any ActivityKit import so it also compiles for macOS.
struct LiveActivitySnapshot: Equatable, Sendable {
    var phase: String
    var isBreak: Bool
    var isPaused: Bool
    var startDate: Date
    var endDate: Date
    var remainingSeconds: Int

    /// Builds the payload for the current timer state, or `nil` when there is
    /// nothing to show (idle, or a phase whose end instant is missing).
    ///
    /// `now` is a parameter so the paused case — which has no absolute end date
    /// and has to synthesise a window around the present — stays testable.
    static func make(
        snapshot: TimerSnapshot,
        endDate: Date?,
        breakEndDate: Date?,
        now: Date
    ) -> LiveActivitySnapshot? {
        switch snapshot.state {
        case .idle:
            return nil

        case .running:
            guard let endDate else { return nil }
            let total = TimeInterval(snapshot.sessionTotalSeconds)
            return LiveActivitySnapshot(
                phase: "专注中",
                isBreak: false,
                isPaused: false,
                startDate: endDate.addingTimeInterval(-total),
                endDate: endDate,
                remainingSeconds: Int(snapshot.remainingSeconds)
            )

        case .paused:
            let remaining = snapshot.remainingSeconds
            let elapsed = max(0, TimeInterval(snapshot.sessionTotalSeconds) - remaining)
            return LiveActivitySnapshot(
                phase: "已暂停",
                isBreak: false,
                isPaused: true,
                startDate: now.addingTimeInterval(-elapsed),
                endDate: now.addingTimeInterval(remaining),
                remainingSeconds: Int(remaining)
            )

        case .breaking:
            guard let breakEndDate else { return nil }
            let total = snapshot.breakTotalSeconds
            return LiveActivitySnapshot(
                phase: "休息中",
                isBreak: true,
                isPaused: false,
                startDate: breakEndDate.addingTimeInterval(-total),
                endDate: breakEndDate,
                remainingSeconds: Int(snapshot.breakRemainingSeconds)
            )
        }
    }
}
