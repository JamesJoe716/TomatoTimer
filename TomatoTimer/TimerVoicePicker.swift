import SwiftUI

struct TimerVoicePicker: View {
    @Binding var voiceGender: String
    let onVoiceGenderChange: @MainActor (String) -> Void
    @AppStorage(SpeechNotifier.mutedDefaultsKey) private var isMuted = false

    var body: some View {
        HStack(spacing: 10) {
            Text("提示音")
                .font(.callout)
                .foregroundStyle(.secondary)

            Picker("提示音", selection: $voiceGender) {
                ForEach(VoiceGender.allCases) { gender in
                    Text(gender.label).tag(gender.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 160)
            .disabled(isMuted)
            .opacity(isMuted ? 0.45 : 1)
            #if os(iOS)
            .onChange(of: voiceGender) { _, newValue in
                onVoiceGenderChange(newValue)
            }
            #else
            .onChange(of: voiceGender) { newValue in
                onVoiceGenderChange(newValue)
            }
            #endif

            Button {
                isMuted.toggle()
            } label: {
                Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.callout)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(isMuted ? Color.secondary : Color.accentColor)
            .accessibilityLabel(isMuted ? "取消静音语音提示" : "静音语音提示")
            .accessibilityValue(isMuted ? "已静音" : "已开启")
        }
    }
}
