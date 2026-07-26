#if os(iOS)
import Foundation
import ActivityKit

/// Shared Live Activity contract between the iOS app and the widget extension.
///
/// The `ContentState` is the per-update payload the app pushes to the running
/// activity; the widget renders whatever state it is handed. No App Group is
/// required because the app drives the activity directly via ActivityKit.
struct PomodoroActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// Localized phase label, e.g. "专注中" / "休息中" / "已暂停".
        var phase: String
        /// True while the break countdown is running.
        var isBreak: Bool
        /// True while the focus countdown is paused.
        var isPaused: Bool
        /// Start of the current phase — used to draw the progress bar.
        var startDate: Date
        /// End of the current phase — drives the self-counting timer text.
        var endDate: Date
        /// Frozen remaining seconds, used when paused (timers can't self-count).
        var pausedRemaining: Int
    }

    /// Static, non-changing name for the session.
    var sessionName: String
}
#endif
