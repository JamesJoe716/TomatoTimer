import SwiftUI

#if os(macOS)
import AppKit
#endif

@MainActor
final class AppActivityMonitor: ObservableObject {
    @Published private(set) var shouldAnimate = true

    private var observers: [NSObjectProtocol] = []
    private let notificationCenter: NotificationCenter

    init(notificationCenter: NotificationCenter = .default) {
        self.notificationCenter = notificationCenter

        #if os(macOS)
        let names: [Notification.Name] = [
            NSApplication.didBecomeActiveNotification,
            NSApplication.didResignActiveNotification,
            NSWindow.didChangeOcclusionStateNotification,
            NSWindow.didMiniaturizeNotification,
            NSWindow.didDeminiaturizeNotification
        ]

        observers = names.map { name in
            notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.refresh()
                }
            }
        }

        Task { @MainActor [weak self] in
            self?.refresh()
        }
        #endif
    }

    func refresh() {
        #if os(macOS)
        let hasVisibleWindow = NSApp.windows.contains { window in
            window.styleMask.contains(.titled) &&
                window.contentView != nil &&
                window.isVisible &&
                !window.isMiniaturized &&
                window.occlusionState.contains(.visible)
        }
        let nextShouldAnimate = NSApp.isActive && hasVisibleWindow

        guard shouldAnimate != nextShouldAnimate else { return }
        shouldAnimate = nextShouldAnimate
        #else
        guard !shouldAnimate else { return }
        shouldAnimate = true
        #endif
    }

    isolated deinit {
        observers.forEach(notificationCenter.removeObserver)
    }
}
