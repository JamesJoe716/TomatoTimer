import SwiftUI

struct CompactDurationStepperView: View {
    let title: String
    let value: Int
    let range: ClosedRange<Int>
    let onChange: @MainActor (Int) -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .frame(width: 34, alignment: .trailing)

            Text(String(format: "%02d", value))
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .frame(width: 58, alignment: .trailing)

            HStack(spacing: 0) {
                StepperIconButton(systemImage: "minus") {
                    onChange(max(range.lowerBound, value - 1))
                }
                .disabled(value <= range.lowerBound)
                .accessibilityLabel("\(title)减少")

                Divider()
                    .frame(height: 28)

                StepperIconButton(systemImage: "plus") {
                    onChange(min(range.upperBound, value + 1))
                }
                .disabled(value >= range.upperBound)
                .accessibilityLabel("\(title)增加")
            }
            .frame(width: 112, height: 44)
            .background(Capsule().fill(Color.secondary.opacity(0.12)))
        }
        .frame(width: 224)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(DurationUnitFormatter.unitName(for: title))
        .accessibilityValue(DurationUnitFormatter.accessibilityValue(title: title, value: value))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                onChange(min(range.upperBound, value + 1))
            case .decrement:
                onChange(max(range.lowerBound, value - 1))
            @unknown default:
                break
            }
        }
    }
}
