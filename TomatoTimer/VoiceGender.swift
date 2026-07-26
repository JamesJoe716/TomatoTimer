import Foundation

enum VoiceGender: String, CaseIterable, Identifiable {
    case female
    case male

    static let defaultsKey = "voiceGender"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .female:
            return "女声"
        case .male:
            return "男声"
        }
    }

    static var current: VoiceGender {
        get {
            guard
                let rawValue = UserDefaults.standard.string(forKey: defaultsKey),
                let gender = VoiceGender(rawValue: rawValue)
            else {
                return .female
            }

            return gender
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: defaultsKey)
        }
    }

    /// Bundle subdirectory holding this voice's pre-rendered clips.
    /// `Audio` is a folder reference, so `Audio/female` ships automatically.
    var clipSubdirectory: String {
        switch self {
        case .male:
            return "Audio"
        case .female:
            return "Audio/female"
        }
    }

    var voiceModeDescription: String {
        switch self {
        case .male:
            return "male(bundled Yunxi clips)"
        case .female:
            return "female(bundled Xiaoyi clips)"
        }
    }

    var selfIntroText: String {
        switch self {
        case .male:
            return "你好,世界首富,我是云希,见证你成为首富所努力的每一分钟。"
        case .female:
            return "你好,世界首富,我是晓伊,见证你成为首富所努力的每一分钟。"
        }
    }
}
