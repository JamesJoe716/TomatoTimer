import SwiftUI

struct TimerDurationEditorView: View {
    @EnvironmentObject private var timer: PomodoroTimerViewModel
    let metrics: AdaptiveLayoutMetrics
    @Binding var voiceGender: String
    let onVoiceGenderChange: @MainActor (String) -> Void

    var body: some View {
        VStack(spacing: 14) {
            VStack(spacing: 14) {
                PresetPickerView(metrics: metrics)
                DurationSteppersView(metrics: metrics)
            }
            .disabled(!timer.canEditDuration)

            TimerVoicePicker(voiceGender: $voiceGender, onVoiceGenderChange: onVoiceGenderChange)
        }
    }
}
