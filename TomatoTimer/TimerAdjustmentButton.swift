import SwiftUI

struct TimerAdjustmentButton: View {
    let title: String
    let systemImage: String
    let action: @MainActor () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .frame(minWidth: 76, maxWidth: .infinity, minHeight: 44)
        }
        .contentShape(Rectangle())
        .buttonStyle(.bordered)
        .controlSize(.regular)
    }
}
