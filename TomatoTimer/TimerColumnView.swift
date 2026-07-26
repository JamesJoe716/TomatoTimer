import SwiftUI

struct TimerColumnView: View {
    @EnvironmentObject private var timer: PomodoroTimerViewModel
    let metrics: AdaptiveLayoutMetrics
    @Binding var voiceGender: String
    let onVoiceGenderChange: @MainActor (String) -> Void

    var body: some View {
        VStack(spacing: metrics.controlSpacing) {
            TimerHeaderView(metrics: metrics)
            TimerFaceView(
                state: timer.state,
                statusText: timer.statusText,
                progress: timer.progress,
                remainingTimeText: timer.remainingTimeText,
                selectedDurationText: timer.selectedDurationText,
                diameter: metrics.ringDiameter
            )
            .frame(width: metrics.ringDiameter, height: metrics.ringDiameter)
            TimerDurationEditorView(
                metrics: metrics,
                voiceGender: $voiceGender,
                onVoiceGenderChange: onVoiceGenderChange
            )
            CountdownAdjustmentsView(metrics: metrics)
            TimerActionsView()
            FocusStatsView()
        }
        .frame(maxWidth: metrics.timerColumnWidth)
    }
}
