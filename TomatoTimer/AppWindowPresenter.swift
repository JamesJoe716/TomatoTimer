import AppKit
import SwiftUI

@MainActor
final class AppWindowPresenter {
    static let shared = AppWindowPresenter()

    private weak var timer: PomodoroTimerViewModel?
    private weak var appActivityMonitor: AppActivityMonitor?
    private var managedWindow: NSWindow?

    private init() { }

    func configure(timer: PomodoroTimerViewModel, appActivityMonitor: AppActivityMonitor) {
        self.timer = timer
        self.appActivityMonitor = appActivityMonitor
    }

    func present() {
        presentNow()
    }

    func presentIfNeeded() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            guard self.visibleMainWindow() == nil else { return }
            self.presentNow()
        }
    }

    func requestAttention() {
        guard !NSApp.isActive else {
            presentNow()
            return
        }

        NSApp.requestUserAttention(.criticalRequest)
    }

    private func presentNow() {
        NSApp.unhide(nil)

        let window = existingMainWindow() ?? createMainWindow()
        window?.deminiaturize(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func visibleMainWindow() -> NSWindow? {
        let window = existingMainWindow()
        return window?.isVisible == true ? window : nil
    }

    private func existingMainWindow() -> NSWindow? {
        if let managedWindow {
            return managedWindow
        }

        return NSApp.windows.first { window in
            window.styleMask.contains(.titled) && window.contentView != nil
        }
    }

    private func createMainWindow() -> NSWindow? {
        guard let timer, let appActivityMonitor else { return nil }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.minSize = NSSize(width: 640, height: 560)
        window.isReleasedWhenClosed = false
        window.title = "番茄钟"
        window.center()
        window.contentView = NSHostingView(
            rootView: ContentView()
                .environmentObject(timer)
                .environmentObject(appActivityMonitor)
        )
        managedWindow = window
        return window
    }
}
