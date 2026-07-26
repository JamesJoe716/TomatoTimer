import SwiftUI

struct TimerFaceView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var appActivityMonitor: AppActivityMonitor

    let state: PomodoroTimerState
    let statusText: String
    let progress: Double
    let remainingTimeText: String
    let selectedDurationText: String
    let diameter: CGFloat

    var body: some View {
        TimelineView(.animation(paused: isTimelinePaused)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            let frame = TimerFaceFrame(state: state, time: time, reduceMotion: reduceMotion)

            ZStack {
                FloatingLightsView(state: state, time: time, reduceMotion: reduceMotion)

                TimerProgressRing(
                    state: state,
                    progress: progress,
                    diameter: diameter,
                    reduceMotion: reduceMotion,
                    glowPhase: frame.glowPhase
                )

                TimerFaceLabels(
                    state: state,
                    remainingTimeText: remainingTimeText,
                    selectedDurationText: selectedDurationText,
                    diameter: diameter,
                    isAnimated: frame.isAnimated,
                    textPhase: frame.textPhase
                )
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("番茄钟计时")
        .accessibilityValue(accessibilityValue)
    }

    private var isAnimatedState: Bool {
        state == .running || state == .breaking
    }

    private var isTimelinePaused: Bool {
        reduceMotion || !appActivityMonitor.shouldAnimate || !isAnimatedState
    }

    private var accessibilityValue: String {
        let percent = Int((progress * 100).rounded())
        return "\(statusText), 剩余 \(spokenClockDuration), 总时长 \(selectedDurationText), 已完成 \(percent)%"
    }

    private var spokenClockDuration: String {
        let parts = remainingTimeText.split(separator: ":").compactMap { Int($0) }

        if parts.count == 3 {
            return "\(parts[0])小时\(parts[1])分\(parts[2])秒"
        }

        if parts.count == 2 {
            return "\(parts[0])分\(parts[1])秒"
        }

        return remainingTimeText
    }
}
