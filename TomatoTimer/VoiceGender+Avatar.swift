import SwiftUI

extension VoiceGender {
    var avatarResourceName: String {
        switch self {
        case .female:
            return "female"
        case .male:
            return "male"
        }
    }

    var avatarDisplayName: String {
        switch self {
        case .female:
            return "晓伊"
        case .male:
            return "云希"
        }
    }

    var avatarGlowColor: Color {
        switch self {
        case .female:
            return Color(red: 1, green: 0.58, blue: 0.78)
        case .male:
            return Color(red: 0.48, green: 0.74, blue: 1)
        }
    }
}
