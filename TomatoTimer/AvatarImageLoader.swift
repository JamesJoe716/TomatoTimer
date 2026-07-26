import SwiftUI
import ImageIO

@MainActor
enum AvatarImageLoader {
    private static let avatarCache: NSCache<NSString, AvatarPlatformImage> = {
        let cache = NSCache<NSString, AvatarPlatformImage>()
        cache.countLimit = 8
        cache.totalCostLimit = 32 * 1024 * 1024
        return cache
    }()

    /// Loads an avatar downsampled to roughly the size it will be drawn at, so a
    /// small (e.g. iPhone) avatar doesn't keep a full-resolution bitmap resident.
    static func avatar(named name: String, maxPixelSize: Int) -> AvatarPlatformImage? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "Avatars") ??
                Bundle.main.url(forResource: name, withExtension: "png"),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }

        // Never upscale past the source resolution.
        let requested = max(64, maxPixelSize)
        let sourceMax = sourceMaxDimension(source)
        let target = sourceMax > 0 ? min(requested, sourceMax) : requested

        let key = "\(name)@\(target)" as NSString
        if let cached = avatarCache.object(forKey: key) {
            return cached
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: target
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }

        #if os(macOS)
        let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        #else
        let image = UIImage(cgImage: cgImage)
        #endif

        avatarCache.setObject(image, forKey: key, cost: cgImage.width * cgImage.height * 4)
        return image
    }

    private static func sourceMaxDimension(_ source: CGImageSource) -> Int {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            return 0
        }
        let width = (properties[kCGImagePropertyPixelWidth] as? Int) ?? 0
        let height = (properties[kCGImagePropertyPixelHeight] as? Int) ?? 0
        return max(width, height)
    }
}
