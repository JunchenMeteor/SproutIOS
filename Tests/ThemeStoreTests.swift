/// 主题存储测试。
/// 断言 group/mode 本设备持久化、默认值（sky/system）、system 模式跟随设备外观、
/// 非法存储值安全回退默认，断网可切（不依赖任何网络）。
@testable import Sprout
import SwiftUI
import XCTest

final class ThemeStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName = ""

    override func setUp() {
        super.setUp()
        suiteName = "ThemeStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    /// 默认 group=sky、mode=system。
    func testDefaultsAreSkyAndSystem() {
        let store = ThemeStore(defaults: defaults)
        XCTAssertEqual(store.group, .sky)
        XCTAssertEqual(store.mode, .system)
    }

    /// 选择写入 UserDefaults，新实例读取一致（本设备保存语义）。
    func testSelectionPersistsAcrossInstances() {
        let store = ThemeStore(defaults: defaults)
        store.setGroup(.lavender)
        store.setMode(.dark)
        let reloaded = ThemeStore(defaults: defaults)
        XCTAssertEqual(reloaded.group, .lavender)
        XCTAssertEqual(reloaded.mode, .dark)
    }

    /// system 模式跟随传入的设备外观；显式 light/dark 不随外观变化。
    func testSystemModeFollowsDeviceAppearance() {
        let store = ThemeStore(defaults: defaults)
        store.setGroup(.peach)
        store.setMode(.system)
        XCTAssertEqual(store.currentTheme(systemScheme: .light).themeId, "PeachLight")
        XCTAssertEqual(store.currentTheme(systemScheme: .dark).themeId, "PeachDark")
        store.setMode(.light)
        XCTAssertEqual(store.currentTheme(systemScheme: .dark).themeId, "PeachLight")
        store.setMode(.dark)
        XCTAssertEqual(store.currentTheme(systemScheme: .light).themeId, "PeachDark")
    }

    /// 存储中的非法值回退默认而不是崩溃。
    func testCorruptStoredValuesFallBackToDefaults() {
        defaults.set("not-a-group", forKey: "themeGroup")
        defaults.set("not-a-mode", forKey: "themeMode")
        let store = ThemeStore(defaults: defaults)
        XCTAssertEqual(store.group, .sky)
        XCTAssertEqual(store.mode, .system)
    }
}
