import ActivityKit
import WidgetKit
import SwiftUI

struct PomodoroLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PomodoroActivityAttributes.self) { context in
            LockScreenLiveActivityView(state: context.state)
                .padding(16)
                .activityBackgroundTint(Color.black.opacity(0.28))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text(context.state.phase)
                            .font(.caption.weight(.semibold))
                    } icon: {
                        Image(systemName: phaseIcon(context.state))
                            .foregroundStyle(accentColor(context.state))
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    timeText(context.state)
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(accentColor(context.state))
                        .frame(maxWidth: 96, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    progressBar(context.state)
                        .tint(accentColor(context.state))
                }
            } compactLeading: {
                Image(systemName: phaseIcon(context.state))
                    .foregroundStyle(accentColor(context.state))
            } compactTrailing: {
                timeText(context.state)
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(accentColor(context.state))
                    .frame(maxWidth: 58)
            } minimal: {
                Image(systemName: phaseIcon(context.state))
                    .foregroundStyle(accentColor(context.state))
            }
            .keylineTint(accentColor(context.state))
        }
    }

    private func phaseIcon(_ state: PomodoroActivityAttributes.ContentState) -> String {
        if state.isPaused { return "pause.circle.fill" }
        return state.isBreak ? "cup.and.saucer.fill" : "flame.fill"
    }

    private func accentColor(_ state: PomodoroActivityAttributes.ContentState) -> Color {
        if state.isPaused { return .orange }
        return state.isBreak
            ? Color(red: 0.42, green: 0.72, blue: 1)
            : Color(red: 1, green: 0.42, blue: 0.62)
    }

    @ViewBuilder
    private func timeText(_ state: PomodoroActivityAttributes.ContentState) -> some View {
        if state.isPaused {
            Text(clock(state.pausedRemaining))
        } else {
            Text(timerInterval: state.startDate...state.endDate, countsDown: true)
                .multilineTextAlignment(.trailing)
        }
    }

    @ViewBuilder
    private func progressBar(_ state: PomodoroActivityAttributes.ContentState) -> some View {
        if state.isPaused {
            ProgressView(value: pausedProgress(state))
        } else {
            ProgressView(timerInterval: state.startDate...state.endDate, countsDown: false) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
        }
    }

    private func pausedProgress(_ state: PomodoroActivityAttributes.ContentState) -> Double {
        let total = state.endDate.timeIntervalSince(state.startDate)
        guard total > 0 else { return 0 }
        let elapsed = total - Double(state.pausedRemaining)
        return min(1, max(0, elapsed / total))
    }

    private func clock(_ seconds: Int) -> String {
        let value = max(0, seconds)
        let hours = value / 3600
        let minutes = (value % 3600) / 60
        let secs = value % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }
}

private struct LockScreenLiveActivityView: View {
    let state: PomodoroActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.18), lineWidth: 5)
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(accent)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(state.phase)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                if state.isPaused {
                    Text(clock(state.pausedRemaining))
                        .font(.system(.title, design: .rounded).weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(accent)
                    ProgressView(value: pausedProgress)
                        .tint(accent)
                } else {
                    Text(timerInterval: state.startDate...state.endDate, countsDown: true)
                        .font(.system(.title, design: .rounded).weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(accent)
                    ProgressView(timerInterval: state.startDate...state.endDate, countsDown: false) {
                        EmptyView()
                    } currentValueLabel: {
                        EmptyView()
                    }
                    .tint(accent)
                }
            }
        }
    }

    private var icon: String {
        if state.isPaused { return "pause.circle.fill" }
        return state.isBreak ? "cup.and.saucer.fill" : "flame.fill"
    }

    private var accent: Color {
        if state.isPaused { return .orange }
        return state.isBreak
            ? Color(red: 0.55, green: 0.8, blue: 1)
            : Color(red: 1, green: 0.55, blue: 0.7)
    }

    private var pausedProgress: Double {
        let total = state.endDate.timeIntervalSince(state.startDate)
        guard total > 0 else { return 0 }
        return min(1, max(0, (total - Double(state.pausedRemaining)) / total))
    }

    private func clock(_ seconds: Int) -> String {
        let value = max(0, seconds)
        let hours = value / 3600
        let minutes = (value % 3600) / 60
        let secs = value % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }
}
