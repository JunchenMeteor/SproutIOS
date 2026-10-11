/// Color 的十六进制初始化扩展。
/// 主题 token 色值唯一权威来源是项目工程规范第 6 节；
/// 本扩展只负责把 #RRGGBB / #RRGGBBAA 字面量解析为 Color，不引入第二套色值。
import SwiftUI

extension Color {
    /// 从十六进制字符串创建颜色。
    /// 支持 #RRGGBB（不透明）与 #RRGGBBAA；非法输入回退为透明黑并在 Debug 下断言。
    init(hex: String) {
        var digits = hex
        if digits.hasPrefix("#") {
            digits.removeFirst()
        }
        let value = UInt64(digits, radix: 16) ?? 0
        switch digits.count {
        case 6:
            self.init(
                red: Double((value >> 16) & 0xFF) / 255,
                green: Double((value >> 8) & 0xFF) / 255,
                blue: Double(value & 0xFF) / 255
            )
        case 8:
            self.init(
                red: Double((value >> 24) & 0xFF) / 255,
                green: Double((value >> 16) & 0xFF) / 255,
                blue: Double((value >> 8) & 0xFF) / 255,
                opacity: Double(value & 0xFF) / 255
            )
        default:
            assertionFailure("非法色值字面量: \(hex)")
            self.init(.black)
        }
    }
}
