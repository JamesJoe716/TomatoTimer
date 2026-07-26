import SwiftUI

struct DurationStepperView: View {
    let title: String
    let value: Int
    let range: ClosedRange<Int>
    let onChange: @MainActor (Int) -> Void

    var body: some View {
        HStack(spacing: 4) {
            StepperIconButton(systemImage: "minus") {
                onChange(max(range.lowerBound, value - 1))
            }
            .disabled(value <= range.lowerBound)
            .accessibilityLabel("\(title)减少")

            HStack(spacing: 4) {
                Text(String(format: "%02d", value))
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                    .frame(minWidth: 34, alignment: .trailing)

                Text(title)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(minWidth: 54)

            StepperIconButton(systemImage: "plus") {
                onChange(min(range.upperBound, value + 1))
            }
            .disabled(value >= range.upperBound)
            .accessibilityLabel("\(title)增加")
        }
        .frame(height: 44)
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
