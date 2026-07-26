import SwiftUI

struct StepperIconButton: View {
    let systemImage: String
    let action: @MainActor () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .frame(width: 55, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
