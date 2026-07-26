import Foundation

struct TimerFaceFrame {
    let state: PomodoroTimerState
    let time: TimeInterval
    let reduceMotion: Bool

    var isAnimated: Bool {
        !reduceMotion && (state == .running || state == .breaking)
    }

    var glowPhase: Double {
        isAnimated ? wave(period: 3) : 0.45
    }

    var textPhase: Double {
        isAnimated && state == .running ? wave(period: 4) : 0
    }

    private func wave(period: TimeInterval) -> Double {
        (sin(time / period * 2 * .pi) + 1) / 2
    }
}
