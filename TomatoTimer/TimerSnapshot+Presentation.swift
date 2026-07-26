import SwiftUI

/// Everything the UI shows that is a pure function of the snapshot.
///
/// These live on the value type rather than the view model so they can be
/// exercised in tests without constructing a timer, and so the view model is
/// left holding only the state machine and its side effects.
extension TimerSnapshot {

    // MARK: - Capabilities

    var canEditDuration: Bool {
        state == .idle
    }

    var canStart: Bool {
        canEditDuration && selectedTotalSeconds > 0
    }

    var canAdjustCountdown: Bool {
        state == .running || state == .paused
    }

    var canSkipBreak: Bool {
        state == .breaking
    }

    // MARK: - Selected duration components

    var selectedHours: Int {
        selectedTotalSeconds / 3600
    }

    var selectedMinutesComponent: Int {
        (selectedTotalSeconds % 3600) / 60
    }

    var selectedSecondsComponent: Int {
        selectedTotalSeconds % 60
    }

    // MARK: - Derived text

    var selectedDurationText: String {
        if state == .breaking {
            return "休息 \(TimerClockFormatter.duration(seconds: breakTotalSeconds))"
        }

        return TimerClockFormatter.duration(seconds: TimeInterval(selectedTotalSeconds))
    }

    var remainingTimeText: String {
        if state == .breaking {
            return TimerClockFormatter.clock(seconds: breakRemainingSeconds, showsHours: false)
        }

        let shouldShowHours = selectedTotalSeconds >= 3600 || remainingSeconds >= 3600
        return TimerClockFormatter.clock(seconds: remainingSeconds, showsHours: shouldShowHours)
    }

    var statusText: String {
        switch state {
        case .idle:
            return "未开始"
        case .running:
            return "进行中"
        case .paused:
            return "已暂停"
        case .breaking:
            return "休息中"
        }
    }

    var statusColor: Color {
        switch state {
        case .idle:
            return .secondary
        case .running:
            return .green
        case .paused:
            return .orange
        case .breaking:
            return .blue
        }
    }

    var progress: Double {
        if state == .breaking {
            guard breakTotalSeconds > 0 else { return 0 }
            return min(1, max(0, 1 - breakRemainingSeconds / breakTotalSeconds))
        }

        guard sessionTotalSeconds > 0 else { return 0 }
        return min(1, max(0, 1 - remainingSeconds / sessionTotalSeconds))
    }

    /// Localized "已休息…,该继续了" message derived from the *active* break length
    /// (so long breaks read correctly). The 5-minute case keeps the exact wording of
    /// the bundled voice clip; other lengths fall back to synthesized speech.
    var breakFinishedMessage: String {
        let totalSeconds = Int(breakTotalSeconds.rounded())
        if totalSeconds == 5 * 60 {
            return "已休息五分钟,该继续了"
        }
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        let phrase = seconds == 0 ? "\(minutes)分钟" : "\(minutes)分\(seconds)秒"
        return "已休息\(phrase),该继续了"
    }
}
