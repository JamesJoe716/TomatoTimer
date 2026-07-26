import SwiftUI

struct DigitalAvatarImage: View {
    let gender: VoiceGender
    let presentation: DigitalAvatarPresentation
    let height: CGFloat
    let metrics: DigitalAvatarFrame
    let reduceMotion: Bool

    var body: some View {
        DigitalAvatarFaceView(gender: gender, reduceMotion: reduceMotion)
            .frame(width: height, height: height)
            .background(
                DigitalAvatarGlowView(
                    color: gender.avatarGlowColor,
                    presentation: presentation,
                    height: height
                )
            )
            .scaleEffect(metrics.scale)
            .opacity(metrics.opacity)
            .offset(metrics.offset)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: gender)
            .animation(reduceMotion ? nil : .spring(response: 0.7, dampingFraction: 0.88), value: presentation)
            .accessibilityLabel("当前提示音: \(gender.label), \(gender == .female ? "晓伊数字人" : "云希数字人")")
    }
}
