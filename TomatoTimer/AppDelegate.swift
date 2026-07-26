import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppWindowPresenter.shared.presentIfNeeded()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            AppWindowPresenter.shared.present()
            return false
        }

        return true
    }
}
