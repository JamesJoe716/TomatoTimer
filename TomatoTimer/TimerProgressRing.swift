import SwiftUI

struct TimerProgressRing: View {
    let state: PomodoroTimerState
    let progress: Double
    let diameter: CGFloat
    let reduceMotion: Bool
    let glowPhase: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(.quaternary, style: ringStroke)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(ringStyle, style: ringStroke)
                .rotationEffect(.degrees(-90))
                .shadow(color: glowColor.opacity(glowOpacity), radius: glowRadius, x: 0, y: 0)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: progress)
        }
    }

    private var ringStroke: StrokeStyle {
        StrokeStyle(lineWidth: ringLineWidth, lineCap: .round)
    }

    private var ringLineWidth: CGFloat {
        clamp(diameter * 0.06, 14, 28)
    }

    private var ringStyle: AnyShapeStyle {
        switch state {
        case .running:
            return AnyShapeStyle(TimerPalette.focusRing)
        case .breaking:
            return AnyShapeStyle(TimerPalette.breakRing)
        case .paused:
            return AnyShapeStyle(TimerPalette.pausedAccent)
        case .idle:
            return AnyShapeStyle(Color.accentColor)
        }
    }

    private var glowColor: Color {
        switch state {
        case .running:
            return TimerPalette.focusGlow
        case .breaking:
            return TimerPalette.breakGlow
        case .paused:
            return .orange
        case .idle:
            return .accentColor
        }
    }

    private var glowOpacity: Double {
        switch state {
        case .running:
            return 0.24 + glowPhase * 0.18
        case .breaking:
            return 0.12 + glowPhase * 0.08
        default:
            return 0.08
        }
    }

    private var glowRadius: Double {
        switch state {
        case .running:
            return 8 + glowPhase * 8
        case .breaking:
            return 5 + glowPhase * 4
        default:
            return 3
        }
    }

    private func clamp(_ value: CGFloat, _ lower: CGFloat, _ upper: CGFloat) -> CGFloat {
        min(max(value, lower), upper)
    }
}
