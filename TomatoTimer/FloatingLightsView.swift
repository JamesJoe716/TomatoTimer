import SwiftUI

struct FloatingLightsView: View {
    let state: PomodoroTimerState
    let time: TimeInterval
    let reduceMotion: Bool

    private static let points: [FloatingLight] = [
        FloatingLight(id: 0, x: 0.18, y: 0.28, size: 8, phase: 0.1, speed: 9),
        FloatingLight(id: 1, x: 0.78, y: 0.22, size: 6, phase: 1.3, speed: 11),
        FloatingLight(id: 2, x: 0.68, y: 0.76, size: 10, phase: 2.1, speed: 13),
        FloatingLight(id: 3, x: 0.25, y: 0.72, size: 7, phase: 3.2, speed: 10),
        FloatingLight(id: 4, x: 0.52, y: 0.16, size: 5, phase: 4.1, speed: 12),
        FloatingLight(id: 5, x: 0.86, y: 0.54, size: 7, phase: 5.0, speed: 14),
        FloatingLight(id: 6, x: 0.12, y: 0.52, size: 6, phase: 5.8, speed: 11),
        FloatingLight(id: 7, x: 0.48, y: 0.86, size: 5, phase: 6.4, speed: 15)
    ]

    var body: some View {
        GeometryReader { proxy in
            if state == .running || state == .breaking {
                ForEach(Self.points) { point in
                    Circle()
                        .fill(lightColor.opacity(lightOpacity(for: point)))
                        .frame(width: point.size, height: point.size)
                        .blur(radius: state == .running ? 2.5 : 1.8)
                        .position(position(for: point, in: proxy.size))
                }
            }
        }
        .allowsHitTesting(false)
    }

    private var lightColor: Color {
        state == .breaking ? Color(red: 0.55, green: 0.82, blue: 1) : Color(red: 1, green: 0.66, blue: 0.76)
    }

    private func lightOpacity(for point: FloatingLight) -> Double {
        let base = state == .breaking ? 0.14 : 0.22
        guard !reduceMotion else { return base * 0.7 }
        let shimmer = (sin(time / point.speed * 2 * .pi + point.phase) + 1) / 2
        return base + shimmer * (state == .breaking ? 0.06 : 0.1)
    }

    private func position(for point: FloatingLight, in size: CGSize) -> CGPoint {
        guard !reduceMotion else {
            return CGPoint(x: size.width * point.x, y: size.height * point.y)
        }

        let driftX = cos(time / point.speed * 2 * .pi + point.phase) * 8
        let driftY = sin(time / (point.speed + 3) * 2 * .pi + point.phase) * 10
        return CGPoint(
            x: size.width * point.x + driftX,
            y: size.height * point.y + driftY
        )
    }
}
