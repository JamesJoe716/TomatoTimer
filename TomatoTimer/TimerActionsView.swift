import SwiftUI

struct TimerActionsView: View {
    @EnvironmentObject private var timer: PomodoroTimerViewModel

    var body: some View {
        HStack(spacing: 12) {
            switch timer.state {
            case .idle:
                TimerActionButton(title: "开始", systemImage: "play.fill", role: .primary, action: timer.start)
                    .disabled(!timer.canStart)
                resetButton
                    .disabled(true)

            case .running:
                TimerActionButton(title: "暂停", systemImage: "pause.fill", role: .primary, action: timer.pause)
                resetButton

            case .paused:
                TimerActionButton(title: "继续", systemImage: "play.fill", role: .primary, action: timer.resume)
                resetButton

            case .breaking:
                TimerActionButton(
                    title: "跳过休息", systemImage: "forward.fill", role: .primary, action: timer.skipBreak
                )
                .disabled(!timer.canSkipBreak)
                resetButton
            }
        }
    }

    /// Identical in every timer state; only `.idle` disables it.
    private var resetButton: some View {
        TimerActionButton(
            title: "重置", systemImage: "arrow.counterclockwise", role: .secondary, action: timer.reset
        )
    }
}
