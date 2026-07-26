import SwiftUI

struct DurationSteppersView: View {
    @EnvironmentObject private var timer: PomodoroTimerViewModel
    let metrics: AdaptiveLayoutMetrics

    var body: some View {
        Group {
            if metrics.isCompact {
                VStack(spacing: 8) {
                    CompactDurationStepperView(title: "时", value: timer.selectedHours, range: 0...23) {
                        timer.setHours($0)
                    }

                    CompactDurationStepperView(title: "分", value: timer.selectedMinutesComponent, range: 0...59) {
                        timer.setMinutesComponent($0)
                    }

                    CompactDurationStepperView(title: "秒", value: timer.selectedSecondsComponent, range: 0...59) {
                        timer.setSecondsComponent($0)
                    }
                }
            } else {
                HStack(spacing: 10) {
                    DurationStepperView(title: "时", value: timer.selectedHours, range: 0...23) {
                        timer.setHours($0)
                    }
                    .frame(width: metrics.durationStepperWidth)

                    Text(":")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)

                    DurationStepperView(title: "分", value: timer.selectedMinutesComponent, range: 0...59) {
                        timer.setMinutesComponent($0)
                    }
                    .frame(width: metrics.durationStepperWidth)

                    Text(":")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)

                    DurationStepperView(title: "秒", value: timer.selectedSecondsComponent, range: 0...59) {
                        timer.setSecondsComponent($0)
                    }
                    .frame(width: metrics.durationStepperWidth)
                }
            }
        }
    }
}
