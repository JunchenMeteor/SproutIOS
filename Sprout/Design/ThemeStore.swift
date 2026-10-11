/// 主题选择的本设备存储与解析。
/// 按规范第 6 节：group（sky/mist/lavender/peach/lemon）与 mode（system/light/dark）
/// 只存本设备 UserDefaults，断网可切，不调用主题 server API，不跨设备强制同步；
/// 切换时已打开的弹层/toast/banner 通过环境注入立即消费新主题。
import SwiftUI

/// 当前主题的环境注入键。默认值是默认组浅色（SkyLight），仅供预览兜底。
private struct ThemeEnvironmentKey: EnvironmentKey {
    static let defaultValue = ThemeFactory.makeTheme(group: .sky, dark: false)
}


extension EnvironmentValues {
    var theme: ThemeTokens {
        get { self[ThemeEnvironmentKey.self] }
        set { self[ThemeEnvironmentKey.self] = newValue }
    }
}


/// 主题选择状态。UserDefaults 注入以便测试隔离。
@Observable
final class ThemeStore {
    private static let groupKey = "themeGroup"
    private static let modeKey = "themeMode"

    private let defaults: UserDefaults

    private(set) var group: ThemeGroup {
        didSet { defaults.set(group.rawValue, forKey: Self.groupKey) }
    }
    private(set) var mode: ThemeMode {
        didSet { defaults.set(mode.rawValue, forKey: Self.modeKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let storedGroup = defaults.string(forKey: Self.groupKey)
        let storedMode = defaults.string(forKey: Self.modeKey)
        self.group = storedGroup.flatMap(ThemeGroup.init(rawValue:)) ?? .sky
        self.mode = storedMode.flatMap(ThemeMode.init(rawValue:)) ?? .system
    }

    func setGroup(_ newGroup: ThemeGroup) {
        group = newGroup
    }

    func setMode(_ newMode: ThemeMode) {
        mode = newMode
    }

    /// 按设备外观解析当前应消费的完整主题。system 模式由调用处传入系统 colorScheme。
    func currentTheme(systemScheme: ColorScheme) -> ThemeTokens {
        let dark: Bool
        switch mode {
        case .system: dark = systemScheme == .dark
        case .light: dark = false
        case .dark: dark = true
        }
        return ThemeFactory.makeTheme(group: group, dark: dark)
    }
}
