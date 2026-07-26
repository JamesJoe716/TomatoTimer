import Foundation

/// Plain, platform-agnostic payload the view layer forwards to the Live Activity.
/// Kept free of any ActivityKit import so it also compiles for macOS.
struct LiveActivitySnapshot: Equatable, Sendable {
    var phase: String
    var isBreak: Bool
    var isPaused: Bool
    var startDate: Date
    var endDate: Date
    var remainingSeconds: Int
}
