import SwiftUI

#if os(macOS)
typealias AvatarPlatformImage = NSImage
#else
typealias AvatarPlatformImage = UIImage
#endif

struct PlatformAvatarImageView: View {
    let image: AvatarPlatformImage

    var body: some View {
        #if os(macOS)
        Image(nsImage: image)
            .resizable()
            .scaledToFit()
        #else
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
        #endif
    }
}
