import SwiftUI

struct DigitalAvatarGlowView: View {
    let color: Color
    let presentation: DigitalAvatarPresentation
    let height: CGFloat

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        color.opacity(presentation == .docked ? 0.18 : 0.28),
                        color.opacity(0)
                    ],
                    center: .center,
                    startRadius: 8,
                    endRadius: height / 2
                )
            )
            .frame(width: height, height: height)
            .blur(radius: 10)
    }
}
