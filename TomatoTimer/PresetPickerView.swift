import SwiftUI

struct PresetPickerView: View {
    @EnvironmentObject private var timer: PomodoroTimerViewModel
    let metrics: AdaptiveLayoutMetrics

    var body: some View {
        Picker("预设", selection: presetSelection) {
            ForEach(timer.availableMinutes, id: \.self) { minutes in
                Text("\(minutes)分")
                    .tag(minutes)
                    .accessibilityLabel("\(minutes)分钟")
            }
        }
        .pickerStyle(.segmented)
        .frame(width: min(320, metrics.timerColumnWidth))
    }

    private var presetSelection: Binding<Int> {
        Binding(
            get: { timer.selectedPresetMinutes ?? 0 },
            set: { minutes in
                guard minutes > 0 else { return }
                timer.selectPreset(minutes: minutes)
            }
        )
    }
}
