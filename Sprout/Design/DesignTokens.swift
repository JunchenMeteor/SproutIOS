/// 排版、间距、圆角与触控尺寸的设计 token。
/// 数值唯一权威来源是项目工程规范第 8 节：
/// title28/section22/body17/helper14/english24 逻辑 pt（支持动态字号），
/// spacing 4/8/12/16/24/32，radius 12/20/24，儿童主触控不小于 48。
/// 页面不直接写字面量，统一消费这里的常量。
import SwiftUI
import UIKit

/// 字号阶梯；经 UIFontMetrics 挂到系统文本样式以支持动态字号。
enum AppFont {
    static var title: Font { scaled(size: 28, weight: .bold, style: .title) }
    static var section: Font { scaled(size: 22, weight: .semibold, style: .title2) }
    static var body: Font { scaled(size: 17, weight: .regular, style: .body) }
    static var helper: Font { scaled(size: 14, weight: .regular, style: .footnote) }
    /// 英语展示文本（参考句、鼓励语）。
    static var english: Font { scaled(size: 24, weight: .medium, style: .title3) }

    private static func scaled(size: CGFloat, weight: Font.Weight, style: Font.TextStyle) -> Font {
        let uiStyle = UIFont.TextStyle(style)
        let scaledSize = UIFontMetrics(forTextStyle: uiStyle).scaledValue(for: size)
        return .system(size: scaledSize, weight: weight)
    }
}


/// 间距阶梯，单位逻辑 pt。
enum AppSpacing {
    static let xxSmall: CGFloat = 4
    static let xSmall: CGFloat = 8
    static let small: CGFloat = 12
    static let medium: CGFloat = 16
    static let large: CGFloat = 24
    static let xLarge: CGFloat = 32
}


/// 圆角阶梯：按钮 12 / 卡片 20 / 弹层 24。
enum AppRadius {
    static let button: CGFloat = 12
    static let card: CGFloat = 20
    static let sheet: CGFloat = 24
}


/// 触控与布局常量。
enum AppLayout {
    /// 儿童主操作最小触控尺寸。
    static let minTouchTarget: CGFloat = 48
    /// 平板/桌面阅读限宽；实际端字号与安全区验证后可调。
    static let readingMaxWidth: CGFloat = 720
    static let wideMaxWidth: CGFloat = 1120
    /// 点击反馈时长（120–180ms 区间中值）。
    static let clickAnimation: Double = 0.15
    /// 页面转场时长（200–300ms 区间中值）。
    static let transitionAnimation: Double = 0.25
}


private extension UIFont.TextStyle {
    init(_ style: Font.TextStyle) {
        switch style {
        case .title: self = .title1
        case .title2: self = .title2
        case .title3: self = .title3
        case .footnote: self = .footnote
        default: self = .body
        }
    }
}
