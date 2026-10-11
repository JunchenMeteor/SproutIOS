/// 语义主题 token 结构。
/// 角色全集与组合规则的唯一权威来源是项目工程规范第 6 节：
/// 四背景、三级文字/图标、按钮/链接/选中/焦点/hover/pressed/disabled、
/// 边界/遮罩/阴影、四语义状态，以及录音/进度/日历/奖励领域角色。
/// 页面与组件只能消费这里的属性，不得硬编码色值。
import SwiftUI

/// 单个语义状态色组：背景、文字、图标同色。
struct StatusColors: Equatable {
    var background: Color
    var foreground: Color
    var icon: Color
}


/// 录音控件的领域角色色组。
/// active 固定组合 error.bg/fg/icon + error.fg 边界；idle 固定 input/text.primary/border。
struct RecordingColors: Equatable {
    var activeBackground: Color
    var activeForeground: Color
    var activeIcon: Color
    var activeBorder: Color
    var idleBackground: Color
    var idleForeground: Color
    var idleBorder: Color
}


/// 日历单元格领域角色：普通/选中/今天/已完成/补卡。
/// 固定组合：cell=card/text.primary，selected=selection，today 外环=focus，
/// complete=success，makeup=info 并叠加文字标识，颜色不作唯一状态信息。
struct CalendarColors: Equatable {
    var cellBackground: Color
    var cellForeground: Color
    var selectedBackground: Color
    var selectedForeground: Color
    var selectedBorder: Color
    var todayRing: Color
    var complete: StatusColors
    var makeup: StatusColors
}


/// 收藏奖励领域角色：卡面/标题/副标题/徽章/待确认/未解锁。
struct RewardColors: Equatable {
    var surface: Color
    var title: Color
    var subtitle: Color
    var badgeBackground: Color
    var badgeForeground: Color
    var pending: StatusColors
    var lockedBackground: Color
    var lockedForeground: Color
}


/// 一套主题（某配色组 × 明或暗）的完整语义 token。
struct ThemeTokens: Equatable {
    var themeId: String
    var accent: Color
    var page: Color
    var card: Color
    var elevated: Color
    var input: Color
    var textPrimary: Color
    var textSecondary: Color
    var textTertiary: Color
    var iconPrimary: Color
    var iconSecondary: Color
    var iconTertiary: Color
    var buttonPrimaryBackground: Color
    var buttonPrimaryForeground: Color
    var buttonPrimaryBorder: Color
    var buttonSecondaryBackground: Color
    var buttonSecondaryForeground: Color
    var buttonSecondaryBorder: Color
    var link: Color
    var highlightBackground: Color
    var highlightForeground: Color
    var selectionBackground: Color
    var selectionForeground: Color
    var selectionBorder: Color
    var focusBorder: Color
    var hoverBackground: Color
    var hoverForeground: Color
    var hoverBorder: Color
    var pressedBackground: Color
    var pressedForeground: Color
    var pressedBorder: Color
    var disabledBackground: Color
    var disabledForeground: Color
    var disabledIcon: Color
    var disabledBorder: Color
    var border: Color
    var divider: Color
    var scrim: Color
    var shadow: Color
    var success: StatusColors
    var warning: StatusColors
    var error: StatusColors
    var info: StatusColors
    var recording: RecordingColors
    var progressTrack: Color
    var progressFill: Color
    var progressBorder: Color
    var progressLabel: Color
    var calendar: CalendarColors
    var reward: RewardColors
}
