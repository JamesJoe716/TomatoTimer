import SwiftUI

@main
struct TomatoTimeriOSApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var timer: PomodoroTimerViewModel
    @StateObject private var appActivityMonitor = AppActivityMonitor()
    @StateObject private var statsStore: FocusStatsStore

    init() {
        let statsStore = FocusStatsStore()
        let timer = PomodoroTimerViewModel(
            onFocusSessionCompleted: { [statsStore] seconds in
                statsStore.record(focusSeconds: seconds)
            }
        )
        _statsStore = StateObject(wrappedValue: statsStore)
        _timer = StateObject(wrappedValue: timer)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(timer)
                .environmentObject(appActivityMonitor)
                .environmentObject(statsStore)
                .onAppear {
                    appActivityMonitor.refresh()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    switch newPhase {
                    case .active:
                        appActivityMonitor.refresh()
                        timer.handleSceneDidBecomeActive()
                    case .background:
                        timer.handleSceneDidEnterBackground()
                    case .inactive:
                        break
                    @unknown default:
                        break
                    }
                }
        }
    }
}
