import SwiftUI

struct AvatarSectionView: View {
    let gender: VoiceGender
    let presentation: DigitalAvatarPresentation
    let isVisible: Bool
    let metrics: AdaptiveLayoutMetrics

    var body: some View {
        DigitalAvatarView(
            gender: gender,
            presentation: presentation,
            isVisible: isVisible,
            height: metrics.avatarHeight
        )
        .frame(width: metrics.avatarWidth, height: metrics.avatarHeight)
    }
}
