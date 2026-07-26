import SwiftUI

@main
struct TomatoTimerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var timer: PomodoroTimerViewModel
    @StateObject private var appActivityMonitor: AppActivityMonitor
    @StateObject private var statsStore: FocusStatsStore

    init() {
        let statsStore = FocusStatsStore()
        let timer = PomodoroTimerViewModel(
            presentBreakAttention: {
                AppWindowPresenter.shared.requestAttention()
            },
            onFocusSessionCompleted: { [statsStore] seconds in
                statsStore.record(focusSeconds: seconds)
            }
        )
        let appActivityMonitor = AppActivityMonitor()
        _statsStore = StateObject(wrappedValue: statsStore)
        _timer = StateObject(wrappedValue: timer)
        _appActivityMonitor = StateObject(wrappedValue: appActivityMonitor)
        AppWindowPresenter.shared.configure(timer: timer, appActivityMonitor: appActivityMonitor)
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
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1100, height: 880)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }

        MenuBarExtra {
            MenuBarTimerView()
                .environmentObject(timer)
                .environmentObject(appActivityMonitor)
                .environmentObject(statsStore)
        } label: {
            MenuBarLabel(timer: timer)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(timer)
        }
    }
}

private struct MenuBarLabel: View {
    @ObservedObject var timer: PomodoroTimerViewModel

    var body: some View {
        if timer.state == .idle {
            Image(systemName: "timer")
        } else {
            Text("🍅 " + timer.remainingTimeText)
        }
    }
}

private struct MenuBarTimerView: View {
    @EnvironmentObject private var timer: PomodoroTimerViewModel

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("番茄钟")
                    .font(.headline)
                Text(timer.statusText)
                    .font(.caption)
                    .foregroundStyle(timer.statusColor)
                    .contentTransition(.opacity)
            }

            ZStack {
                TimerProgressRing(
                    state: timer.state,
                    progress: timer.progress,
                    diameter: 132,
                    reduceMotion: true,
                    glowPhase: 0
                )
                .frame(width: 132, height: 132)

                VStack(spacing: 2) {
                    Text(timer.remainingTimeText)
                        .font(.system(size: 27, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text(timer.selectedDurationText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 10) {
                Button(action: togglePrimary) {
                    Label(primaryTitle, systemImage: primaryIcon)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(timer.state == .idle && !timer.canStart)

                Button {
                    timer.reset()
                } label: {
                    Label("重置", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)
                .disabled(timer.state == .idle)
            }

            Divider()

            Button {
                AppWindowPresenter.shared.requestAttention()
            } label: {
                Label("打开主窗口", systemImage: "macwindow")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderless)
        }
        .padding(18)
        .frame(width: 264)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: timer.state)
    }

    private var primaryTitle: String {
        switch timer.state {
        case .idle: return "开始"
        case .running: return "暂停"
        case .paused: return "继续"
        case .breaking: return "跳过休息"
        }
    }

    private var primaryIcon: String {
        switch timer.state {
        case .idle, .paused: return "play.fill"
        case .running: return "pause.fill"
        case .breaking: return "forward.fill"
        }
    }

    private func togglePrimary() {
        switch timer.state {
        case .idle:
            timer.start()
        case .running:
            timer.pause()
        case .paused:
            timer.resume()
        case .breaking:
            timer.skipBreak()
        }
    }
}
