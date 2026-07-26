import SwiftUI

struct DigitalAvatarView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var appActivityMonitor: AppActivityMonitor

    let gender: VoiceGender
    let presentation: DigitalAvatarPresentation
    let isVisible: Bool
    let height: CGFloat

    var body: some View {
        TimelineView(.animation(paused: reduceMotion || !appActivityMonitor.shouldAnimate)) { context in
            let metrics = DigitalAvatarFrame(
                time: context.date.timeIntervalSinceReferenceDate,
                presentation: presentation,
                isVisible: isVisible,
                reduceMotion: reduceMotion
            )

            DigitalAvatarImage(
                gender: gender,
                presentation: presentation,
                height: height,
                metrics: metrics,
                reduceMotion: reduceMotion
            )
        }
        .frame(width: height, height: height, alignment: .center)
        .allowsHitTesting(false)
    }
}
