import SwiftUI

struct DigitalAvatarFrame {
    let time: TimeInterval
    let presentation: DigitalAvatarPresentation
    let isVisible: Bool
    let reduceMotion: Bool

    var isIntroducing: Bool {
        presentation == .introducing
    }

    var breathScale: Double {
        reduceMotion ? 1 : 1 + (sin(time / 4.4 * 2 * .pi) + 1) / 2 * 0.014
    }

    var floatOffset: Double {
        reduceMotion ? 0 : sin(time / 3.8 * 2 * .pi) * 4
    }

    var scale: Double {
        (isIntroducing ? 1.04 : breathScale) * (isVisible ? 1 : 0.96)
    }

    var opacity: Double {
        isVisible ? 0.98 : 0
    }

    var offset: CGSize {
        CGSize(
            width: isIntroducing ? (reduceMotion ? 0 : 22) : 0,
            height: isIntroducing ? (reduceMotion ? 0 : 8) : floatOffset
        )
    }
}
