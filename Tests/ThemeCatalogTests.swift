/// 主题目录与工厂测试。
/// 断言十套主题完整生成、ID 稳定、关键 token 与规范第 6 节色值一致；
/// 这是配色源数据测试，不代替 UI/读屏/真机验收。
@testable import Sprout
import SwiftUI
import XCTest

final class ThemeCatalogTests: XCTestCase {
    /// 五个配色组 × 明暗共十套，ID 为规范稳定值且不重复。
    func testTenThemesHaveStableUniqueIds() {
        var ids: [String] = []
        for group in ThemeGroup.allCases {
            ids.append(ThemeFactory.makeTheme(group: group, dark: false).themeId)
            ids.append(ThemeFactory.makeTheme(group: group, dark: true).themeId)
        }
        XCTAssertEqual(ids.count, 10)
        XCTAssertEqual(Set(ids).count, 10)
        XCTAssertEqual(Set(ids), Set(ThemeCatalog.allThemeIds))
    }

    /// SkyLight 基础色与规范第 6 节一致。
    func testSkyLightBaseColorsMatchSpec() {
        let theme = ThemeFactory.makeTheme(group: .sky, dark: false)
        XCTAssertEqual(theme.themeId, "SkyLight")
        XCTAssertEqual(theme.accent, Color(hex: "#87CEFA"))
        XCTAssertEqual(theme.page, Color(hex: "#FAF8F3"))
        XCTAssertEqual(theme.card, Color(hex: "#FFFFFF"))
        XCTAssertEqual(theme.elevated, Color(hex: "#FFFFFF"))
        XCTAssertEqual(theme.input, Color(hex: "#F0F3F8"))
    }

    /// LemonDark 基础色与规范一致（抽查深色组映射）。
    func testLemonDarkBaseColorsMatchSpec() {
        let theme = ThemeFactory.makeTheme(group: .lemon, dark: true)
        XCTAssertEqual(theme.themeId, "LemonDark")
        XCTAssertEqual(theme.accent, Color(hex: "#A7C7E7"))
        XCTAssertEqual(theme.page, Color(hex: "#181C22"))
        XCTAssertEqual(theme.elevated, Color(hex: "#303741"))
        XCTAssertEqual(theme.input, Color(hex: "#1F252D"))
    }

    /// 主按钮规范：accent 底 + #14243B 字，禁止白字；浅色边框 #14243B，深色边框 #AAB8CD。
    func testPrimaryButtonUsesDarkTextOnAccent() {
        for group in ThemeGroup.allCases {
            let light = ThemeFactory.makeTheme(group: group, dark: false)
            XCTAssertEqual(light.buttonPrimaryBackground, light.accent)
            XCTAssertEqual(light.buttonPrimaryForeground, Color(hex: "#14243B"))
            XCTAssertEqual(light.buttonPrimaryBorder, Color(hex: "#14243B"))
            let dark = ThemeFactory.makeTheme(group: group, dark: true)
            XCTAssertEqual(dark.buttonPrimaryBackground, dark.accent)
            XCTAssertEqual(dark.buttonPrimaryForeground, Color(hex: "#14243B"))
            XCTAssertEqual(dark.buttonPrimaryBorder, Color(hex: "#AAB8CD"))
        }
    }

    /// 领域固定组合：录音 active=error 色组、日历 today 环=focus、奖励 badge=highlight。
    func testDomainRolesFollowFixedCombinationRules() {
        let light = ThemeFactory.makeTheme(group: .mist, dark: false)
        XCTAssertEqual(light.recording.activeBackground, light.error.background)
        XCTAssertEqual(light.recording.activeForeground, light.error.foreground)
        XCTAssertEqual(light.recording.activeBorder, light.error.foreground)
        XCTAssertEqual(light.recording.idleBackground, light.input)
        XCTAssertEqual(light.calendar.todayRing, light.focusBorder)
        XCTAssertEqual(light.calendar.selectedBackground, light.selectionBackground)
        XCTAssertEqual(light.calendar.complete.background, light.success.background)
        XCTAssertEqual(light.calendar.makeup.background, light.info.background)
        XCTAssertEqual(light.reward.badgeBackground, light.accent)
        XCTAssertEqual(light.reward.lockedBackground, light.input)
        XCTAssertEqual(light.reward.pending.background, light.info.background)
        XCTAssertEqual(light.progressFill, light.link)
        let dark = ThemeFactory.makeTheme(group: .mist, dark: true)
        XCTAssertEqual(dark.progressFill, dark.accent)
        XCTAssertEqual(dark.focusBorder, dark.accent)
    }

    /// 状态色组文字与图标同色（规范：图标与文字同色）。
    func testStatusIconMatchesForeground() {
        for group in ThemeGroup.allCases {
            for dark in [false, true] {
                let theme = ThemeFactory.makeTheme(group: group, dark: dark)
                for status in [theme.success, theme.warning, theme.error, theme.info] {
                    XCTAssertEqual(status.icon, status.foreground)
                }
            }
        }
    }

    /// scrim/shadow 为规范固定值。
    func testScrimAndShadowFixedValues() {
        let light = ThemeFactory.makeTheme(group: .sky, dark: false)
        XCTAssertEqual(light.scrim, Color(hex: "#00000080"))
        XCTAssertEqual(light.shadow, Color(hex: "#14243B26"))
        let dark = ThemeFactory.makeTheme(group: .sky, dark: true)
        XCTAssertEqual(dark.scrim, Color(hex: "#00000080"))
        XCTAssertEqual(dark.shadow, Color(hex: "#00000066"))
    }
}
