import SwiftUI

struct DigitalAvatarFaceView: View {
    @Environment(\.displayScale) private var displayScale
    let gender: VoiceGender
    let reduceMotion: Bool

    var body: some View {
        GeometryReader { proxy in
            let maxPixel = Self.targetPixelSize(for: proxy.size, scale: displayScale)

            Group {
                if let image = AvatarImageLoader.avatar(named: gender.avatarResourceName, maxPixelSize: maxPixel) {
                    PlatformAvatarImageView(image: image)
                } else {
                    Circle()
                        .fill(.quaternary)
                        .overlay(
                            Text(gender.avatarDisplayName)
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.secondary)
                        )
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .id(gender.rawValue)
        .transition(avatarTransition)
    }

    /// The avatar is drawn at `size` points; downsample to that many device pixels,
    /// quantized up to 128px buckets so the cache stays small.
    private static func targetPixelSize(for size: CGSize, scale: CGFloat) -> Int {
        let points = max(size.width, size.height)
        let pixels = points * scale
        let bucket = 128.0
        return max(128, Int((pixels / bucket).rounded(.up) * bucket))
    }

    private var avatarTransition: AnyTransition {
        if reduceMotion {
            return .opacity
        }

        return .asymmetric(
            insertion: .opacity.combined(with: .move(edge: .leading)).combined(with: .scale(scale: 0.96)),
            removal: .opacity.combined(with: .move(edge: .leading)).combined(with: .scale(scale: 0.96))
        )
    }
}
