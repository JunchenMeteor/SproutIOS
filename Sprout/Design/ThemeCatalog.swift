/// 十套主题的配色组与每套基础色表。
/// 色值唯一权威来源是项目工程规范第 6 节，本文件只是忠实映射；
/// 主题 ID 为 UpperCamelCase 稳定协议值（如 SkyLight），
/// 设备存储的 group 键为 lowerCamelCase（sky/mist/lavender/peach/lemon），
/// mode 为 system/light/dark；两类键的映射在此唯一定义，不并存第二套。
import SwiftUI

/// 配色组存储键。sky 为默认组。
enum ThemeGroup: String, CaseIterable, Sendable {
    case sky
    case mist
    case lavender
    case peach
    case lemon
}


/// 明暗模式选择；system 跟随设备外观。
enum ThemeMode: String, CaseIterable, Sendable {
    case system
    case light
    case dark
}


/// 一套主题随组变化的基础色；其余语义 token 由明/暗共享表按固定组合规则生成。
struct ThemeBaseColors: Equatable {
    var themeId: String
    var accent: Color
    var page: Color
    var card: Color
    var elevated: Color
    var input: Color
}


/// 十套主题基础色查询。
enum ThemeCatalog {
    /// 全部十套主题的稳定 ID，供验收遍历。
    static let allThemeIds = [
        "SkyLight", "SkyDark", "MistLight", "MistDark", "LavenderLight",
        "LavenderDark", "PeachLight", "PeachDark", "LemonLight", "LemonDark",
    ]

    /// 按配色组与明暗取基础色。dark 为 true 时取该组 Dark 套。
    static func baseColors(group: ThemeGroup, dark: Bool) -> ThemeBaseColors {
        switch (group, dark) {
        case (.sky, false):
            return ThemeBaseColors(themeId: "SkyLight", accent: Color(hex: "#87CEFA"),
                page: Color(hex: "#FAF8F3"), card: Color(hex: "#FFFFFF"),
                elevated: Color(hex: "#FFFFFF"), input: Color(hex: "#F0F3F8"))
        case (.sky, true):
            return ThemeBaseColors(themeId: "SkyDark", accent: Color(hex: "#87CEFA"),
                page: Color(hex: "#101827"), card: Color(hex: "#192338"),
                elevated: Color(hex: "#22304A"), input: Color(hex: "#141E30"))
        case (.mist, false):
            return ThemeBaseColors(themeId: "MistLight", accent: Color(hex: "#B8D4F0"),
                page: Color(hex: "#F7F9FC"), card: Color(hex: "#FFFFFF"),
                elevated: Color(hex: "#FFFFFF"), input: Color(hex: "#EEF3F9"))
        case (.mist, true):
            return ThemeBaseColors(themeId: "MistDark", accent: Color(hex: "#8BAAF5"),
                page: Color(hex: "#111A30"), card: Color(hex: "#1B2740"),
                elevated: Color(hex: "#25324D"), input: Color(hex: "#152139"))
        case (.lavender, false):
            return ThemeBaseColors(themeId: "LavenderLight", accent: Color(hex: "#C4B5FD"),
                page: Color(hex: "#FAF8FF"), card: Color(hex: "#FFFFFF"),
                elevated: Color(hex: "#FFFFFF"), input: Color(hex: "#F1EDFA"))
        case (.lavender, true):
            return ThemeBaseColors(themeId: "LavenderDark", accent: Color(hex: "#B9A0FF"),
                page: Color(hex: "#1B162A"), card: Color(hex: "#272038"),
                elevated: Color(hex: "#332944"), input: Color(hex: "#201B31"))
        case (.peach, false):
            return ThemeBaseColors(themeId: "PeachLight", accent: Color(hex: "#FDBA9A"),
                page: Color(hex: "#FFF8F2"), card: Color(hex: "#FFFFFF"),
                elevated: Color(hex: "#FFFFFF"), input: Color(hex: "#F9EEE5"))
        case (.peach, true):
            return ThemeBaseColors(themeId: "PeachDark", accent: Color(hex: "#F2BB67"),
                page: Color(hex: "#211B16"), card: Color(hex: "#30271F"),
                elevated: Color(hex: "#3C3026"), input: Color(hex: "#29211B"))
        case (.lemon, false):
            return ThemeBaseColors(themeId: "LemonLight", accent: Color(hex: "#F4D96B"),
                page: Color(hex: "#FFFCF1"), card: Color(hex: "#FFFFFF"),
                elevated: Color(hex: "#FFFFFF"), input: Color(hex: "#F5F0DC"))
        case (.lemon, true):
            return ThemeBaseColors(themeId: "LemonDark", accent: Color(hex: "#A7C7E7"),
                page: Color(hex: "#181C22"), card: Color(hex: "#252B33"),
                elevated: Color(hex: "#303741"), input: Color(hex: "#1F252D"))
        }
    }
}
