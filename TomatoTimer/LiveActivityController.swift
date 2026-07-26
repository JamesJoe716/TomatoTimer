#if os(iOS)
import Foundation
import ActivityKit

/// Drives the Pomodoro Live Activity (lock screen + Dynamic Island) from the
/// app side. Stateless — the running activity is discovered through
/// `Activity.activities`, so a single `sync` entry point can start, update, or
/// end the activity as the timer state changes.
@MainActor
enum LiveActivityController {
    static func sync(_ snapshot: LiveActivitySnapshot?) async {
        guard let snapshot else {
            await end()
            return
        }

        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let content = PomodoroActivityAttributes.ContentState(
            phase: snapshot.phase,
            isBreak: snapshot.isBreak,
            isPaused: snapshot.isPaused,
            startDate: snapshot.startDate,
            endDate: snapshot.endDate,
            pausedRemaining: snapshot.remainingSeconds
        )

        if let activity = Activity<PomodoroActivityAttributes>.activities.first {
            await activity.update(ActivityContent(state: content, staleDate: nil))
        } else {
            let attributes = PomodoroActivityAttributes(sessionName: "番茄钟")
            _ = try? Activity.request(
                attributes: attributes,
                content: ActivityContent(state: content, staleDate: nil),
                pushType: nil
            )
        }
    }

    static func end() async {
        for activity in Activity<PomodoroActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
#endif
