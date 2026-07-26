import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var timer: PomodoroTimerViewModel
    @AppStorage(SpeechNotifier.mutedDefaultsKey) private var isMuted = false
    @AppStorage(PomodoroTimerViewModel.autoStartDefaultsKey) private var autoStartNextFocus = false
    @AppStorage(PomodoroTimerViewModel.longBreakIntervalDefaultsKey) private var longBreakInterval = 0
    @AppStorage(PomodoroTimerViewModel.longBreakMinutesDefaultsKey) private var longBreakMinutes = 15

    var body: some View {
        Form {
            Section("休息时长") {
                Stepper(value: breakMinutesBinding, in: 1...60) {
                    HStack {
                        Text("每次休息")
                        Spacer()
                        Text("\(timer.breakMinutes) 分钟")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                .disabled(!timer.canEditDuration)

                if !timer.canEditDuration {
                    Text("计时进行中,休息时长暂不可修改")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("休息节奏") {
                Toggle("休息后自动开始下一段", isOn: $autoStartNextFocus)

                Stepper(value: $longBreakInterval, in: 0...12) {
                    HStack {
                        Text("长休息间隔")
                        Spacer()
                        Text(longBreakInterval == 0 ? "关闭" : "每 \(longBreakInterval) 段")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }

                if longBreakInterval > 0 {
                    Stepper(value: $longBreakMinutes, in: 1...60) {
                        HStack {
                            Text("长休息时长")
                            Spacer()
                            Text("\(longBreakMinutes) 分钟")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                }
            }

            Section("语音提示") {
                Toggle("静音语音提示", isOn: $isMuted)
            }
        }
        .formStyle(.grouped)
        #if os(macOS)
        .frame(minWidth: 380, minHeight: 240)
        #endif
    }

    private var breakMinutesBinding: Binding<Int> {
        Binding(
            get: { timer.breakMinutes },
            set: { timer.setBreakMinutes($0) }
        )
    }
}
