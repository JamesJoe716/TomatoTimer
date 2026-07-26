enum DurationUnitFormatter {
    static func unitName(for title: String) -> String {
        switch title {
        case "时":
            return "小时"
        case "分":
            return "分钟"
        case "秒":
            return "秒钟"
        default:
            return title
        }
    }

    static func accessibilityValue(title: String, value: Int) -> String {
        "\(value)\(unitName(for: title))"
    }
}
