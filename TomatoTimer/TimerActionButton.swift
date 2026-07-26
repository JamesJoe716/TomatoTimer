import SwiftUI

struct TimerActionButton: View {
    enum Role {
        case primary
        case secondary
    }

    let title: String
    let systemImage: String
    let role: Role
    let action: @MainActor () -> Void

    var body: some View {
        switch role {
        case .primary:
            Button(action: action) {
                Label(title, systemImage: systemImage)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .frame(minWidth: 96)
            }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        case .secondary:
            Button(action: action) {
                Label(title, systemImage: systemImage)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .frame(minWidth: 96)
            }
                .buttonStyle(.bordered)
                .controlSize(.large)
        }
    }
}
