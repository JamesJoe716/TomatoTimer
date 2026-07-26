import SwiftUI

struct AdaptiveLayoutMetrics {
    let size: CGSize
    let dynamicTypeSize: DynamicTypeSize

    var isCompact: Bool {
        size.width < 720 || size.height < 620 || dynamicTypeSize.isAccessibilitySize
    }

    var minSide: CGFloat {
        min(size.width, size.height)
    }

    var horizontalPadding: CGFloat {
        clamp(size.width * 0.035, 16, 48)
    }

    var verticalPadding: CGFloat {
        clamp(size.height * 0.035, 18, 42)
    }

    var sectionSpacing: CGFloat {
        isCompact ? clamp(size.height * 0.014, 10, 18) : clamp(size.width * 0.035, 28, 72)
    }

    var controlSpacing: CGFloat {
        isCompact ? clamp(size.height * 0.018, 12, 18) : clamp(size.height * 0.025, 16, 24)
    }

    var ringDiameter: CGFloat {
        let compactLimit = isCompact ? size.width * 0.58 : .infinity
        let minimumDiameter: CGFloat = dynamicTypeSize.isAccessibilitySize ? 260 : 220
        return min(clamp(minSide * 0.42, minimumDiameter, 560), compactLimit)
    }

    var timerColumnWidth: CGFloat {
        if isCompact {
            let availableWidth = size.width - horizontalPadding * 2
            return min(clamp(availableWidth, 320, 520), availableWidth)
        }

        return clamp(size.width * 0.38, 360, 560)
    }

    var durationStepperWidth: CGFloat {
        guard !isCompact else { return clamp((timerColumnWidth - 52) / 3, 88, 112) }
        return 112
    }

    var usesSingleColumnCountdownAdjustments: Bool {
        dynamicTypeSize.isAccessibilitySize || timerColumnWidth < 390
    }

    var avatarHeight: CGFloat {
        let target = clamp(size.height * 0.72, 260, 900)

        if isCompact {
            return min(target, clamp(size.height * 0.16, 124, 170), size.width - horizontalPadding * 2)
        }

        let availableWidth = max(260, size.width - horizontalPadding * 2 - sectionSpacing - timerColumnWidth)
        return min(target, availableWidth)
    }

    var avatarWidth: CGFloat {
        avatarHeight
    }

    var maxContentWidth: CGFloat {
        if isCompact {
            return min(size.width - horizontalPadding * 2, 560)
        }

        return timerColumnWidth + sectionSpacing + avatarWidth
    }

    private func clamp(_ value: CGFloat, _ lower: CGFloat, _ upper: CGFloat) -> CGFloat {
        min(max(value, lower), upper)
    }
}
