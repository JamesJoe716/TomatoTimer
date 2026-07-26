import SwiftUI

/// Central brand palette for the timer UI. Single source of truth for the
/// focus / break / paused / idle colours and their gradients, so the look stays
/// consistent across the ring, the time labels, and the stats card — and can be
/// themed from one place later. Values match what each view used inline before.
enum TimerPalette {
    // MARK: - Focus (work): warm pink → coral → amber → violet

    static let focusRing = AngularGradient(
        colors: [
            Color(red: 1, green: 0.42, blue: 0.67),
            Color(red: 1, green: 0.48, blue: 0.38),
            Color(red: 1, green: 0.78, blue: 0.33),
            Color(red: 0.72, green: 0.58, blue: 1),
            Color(red: 1, green: 0.42, blue: 0.67)
        ],
        center: .center
    )

    static let focusText = LinearGradient(
        colors: [
            Color(red: 1, green: 0.38, blue: 0.62),
            Color(red: 1, green: 0.63, blue: 0.42),
            Color(red: 0.61, green: 0.51, blue: 1)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let focusGlow = Color(red: 1, green: 0.5, blue: 0.62)

    // MARK: - Break: cool blues

    static let breakRing = AngularGradient(
        colors: [
            Color(red: 0.45, green: 0.72, blue: 1),
            Color(red: 0.62, green: 0.86, blue: 1),
            Color(red: 0.54, green: 0.65, blue: 1),
            Color(red: 0.45, green: 0.72, blue: 1)
        ],
        center: .center
    )

    static let breakText = LinearGradient(
        colors: [
            Color(red: 0.34, green: 0.62, blue: 1),
            Color(red: 0.55, green: 0.8, blue: 1)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let breakGlow = Color(red: 0.42, green: 0.72, blue: 1)

    // MARK: - Paused / idle

    static let pausedAccent = Color.orange

    // MARK: - Stats card accent

    static let statsAccent = LinearGradient(
        colors: [
            Color(red: 1, green: 0.42, blue: 0.67),
            Color(red: 1, green: 0.6, blue: 0.4),
            Color(red: 0.72, green: 0.58, blue: 1)
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
}
