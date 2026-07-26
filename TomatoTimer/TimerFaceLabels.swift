import SwiftUI

struct TimerFaceLabels: View {
    @ScaledMetric(relativeTo: .largeTitle) private var timerTextScale: CGFloat = 1
    @ScaledMetric(relativeTo: .headline) private var durationTextScale: CGFloat = 1

    let state: PomodoroTimerState
    let remainingTimeText: String
    let selectedDurationText: String
    let diameter: CGFloat
    let isAnimated: Bool
    let textPhase: Double

    var body: some View {
        VStack(spacing: 6) {
            Text(remainingTimeText)
                .font(.system(size: timeFontSize * timerTextScale, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(timeTextStyle)
                .scaleEffect(isAnimated && state == .running ? 1 + textPhase * 0.025 : 1)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(selectedDurationText)
                .font(.system(size: max(13, diameter * 0.052) * durationTextScale, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    private var timeFontSize: CGFloat {
        let base = diameter * 0.24
        return remainingTimeText.count > 5 ? base * 0.8 : base
    }

    private var timeTextStyle: AnyShapeStyle {
        switch state {
        case .running:
            return AnyShapeStyle(TimerPalette.focusText)
        case .breaking:
            return AnyShapeStyle(TimerPalette.breakText)
        default:
            return AnyShapeStyle(Color.primary)
        }
    }
}
