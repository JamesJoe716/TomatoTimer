import Foundation

/// Pure clock/duration formatting for the timer's derived text.
enum TimerClockFormatter {
    /// `mm:ss`, or `hh:mm:ss` when `showsHours`.
    ///
    /// Rounds up, so a running timer never reads 00:00 while time remains.
    static func clock(seconds: TimeInterval, showsHours: Bool) -> String {
        let totalSeconds = max(0, Int(ceil(seconds)))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if showsHours {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }

        return String(format: "%02d:%02d", minutes, seconds)
    }

    /// Spoken-style duration: `1小时 05分 00秒`, `25分 00秒`, or `30秒`.
    static func duration(seconds: TimeInterval) -> String {
        let totalSeconds = max(0, Int(seconds))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d小时 %02d分 %02d秒", hours, minutes, seconds)
        }

        if minutes > 0 {
            return String(format: "%d分 %02d秒", minutes, seconds)
        }

        return "\(seconds)秒"
    }
}
