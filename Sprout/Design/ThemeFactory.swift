/// 由基础色 + 明/暗共享语义表生成完整 ThemeTokens。
/// 组合规则唯一权威来源是项目工程规范第 6 节：
/// 主按钮 accent 底 + #14243B 字与必要深边框（禁止白字）；
/// 领域角色（录音/进度/日历/奖励）按下述固定规则派生，不在页面另配。
import SwiftUI

enum ThemeFactory {
    /// 生成一套完整主题。dark 决定使用深色共享表与 progressFill=accent。
    static func makeTheme(group: ThemeGroup, dark: Bool) -> ThemeTokens {
        let base = ThemeCatalog.baseColors(group: group, dark: dark)
        let textPrimary = Color(hex: dark ? "#F2F5FC" : "#14243B")
        let border = Color(hex: dark ? "#AAB8CD" : "#526078")
        let link = Color(hex: dark ? "#B8D4F0" : "#244F85")
        let success = StatusColors(
            background: Color(hex: dark ? "#14392A" : "#E8F5EE"),
            foreground: Color(hex: dark ? "#A6E7C4" : "#145238"),
            icon: Color(hex: dark ? "#A6E7C4" : "#145238"))
        let warning = StatusColors(
            background: Color(hex: dark ? "#3D3015" : "#FFF0CF"),
            foreground: Color(hex: dark ? "#F7D58A" : "#624300"),
            icon: Color(hex: dark ? "#F7D58A" : "#624300"))
        let error = StatusColors(
            background: Color(hex: dark ? "#40202A" : "#FDECEF"),
            foreground: Color(hex: dark ? "#FFB4C0" : "#8B2034"),
            icon: Color(hex: dark ? "#FFB4C0" : "#8B2034"))
        let info = StatusColors(
            background: Color(hex: dark ? "#1B304C" : "#EAF2FC"),
            foreground: Color(hex: dark ? "#B8D4F0" : "#244F85"),
            icon: Color(hex: dark ? "#B8D4F0" : "#244F85"))
        let selection = (
            background: base.accent,
            foreground: Color(hex: "#14243B"),
            border: Color(hex: "#14243B"))
        let focusBorder = dark ? base.accent : Color(hex: "#244F85")
        let recording = RecordingColors(
            activeBackground: error.background, activeForeground: error.foreground,
            activeIcon: error.icon, activeBorder: error.foreground,
            idleBackground: base.input, idleForeground: textPrimary, idleBorder: border)
        let calendar = CalendarColors(
            cellBackground: base.card, cellForeground: textPrimary,
            selectedBackground: selection.background, selectedForeground: selection.foreground,
            selectedBorder: selection.border, todayRing: focusBorder,
            complete: success, makeup: info)
        let reward = RewardColors(
            surface: base.card, title: textPrimary,
            subtitle: Color(hex: dark ? "#D1D9E8" : "#405168"),
            badgeBackground: base.accent, badgeForeground: Color(hex: "#14243B"),
            pending: info,
            lockedBackground: base.input,
            lockedForeground: Color(hex: dark ? "#AAB8CD" : "#526078"))
        return ThemeTokens(
            themeId: base.themeId,
            accent: base.accent, page: base.page, card: base.card,
            elevated: base.elevated, input: base.input,
            textPrimary: textPrimary,
            textSecondary: Color(hex: dark ? "#D1D9E8" : "#405168"),
            textTertiary: Color(hex: dark ? "#AAB8CD" : "#526078"),
            iconPrimary: textPrimary,
            iconSecondary: Color(hex: dark ? "#D1D9E8" : "#405168"),
            iconTertiary: Color(hex: dark ? "#AAB8CD" : "#526078"),
            buttonPrimaryBackground: base.accent,
            buttonPrimaryForeground: Color(hex: "#14243B"),
            buttonPrimaryBorder: Color(hex: dark ? "#AAB8CD" : "#14243B"),
            buttonSecondaryBackground: base.card,
            buttonSecondaryForeground: textPrimary,
            buttonSecondaryBorder: border,
            link: link,
            highlightBackground: base.accent,
            highlightForeground: Color(hex: "#14243B"),
            selectionBackground: selection.background,
            selectionForeground: selection.foreground,
            selectionBorder: selection.border,
            focusBorder: focusBorder,
            hoverBackground: base.input, hoverForeground: textPrimary, hoverBorder: border,
            pressedBackground: base.input, pressedForeground: textPrimary,
            pressedBorder: Color(hex: dark ? "#F2F5FC" : "#14243B"),
            disabledBackground: Color(hex: dark ? "#2A3446" : "#E4E7ED"),
            disabledForeground: Color(hex: dark ? "#AAB8CD" : "#526078"),
            disabledIcon: Color(hex: dark ? "#AAB8CD" : "#526078"),
            disabledBorder: Color(hex: dark ? "#AAB8CD" : "#526078"),
            border: border, divider: border,
            scrim: Color(hex: "#00000080"),
            shadow: Color(hex: dark ? "#00000066" : "#14243B26"),
            success: success, warning: warning, error: error, info: info,
            recording: recording,
            progressTrack: base.input,
            progressFill: dark ? base.accent : link,
            progressBorder: border,
            progressLabel: textPrimary,
            calendar: calendar,
            reward: reward)
    }
}
