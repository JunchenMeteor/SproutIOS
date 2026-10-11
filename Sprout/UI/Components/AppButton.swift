/// 通用按钮组件。
/// 统一三类按钮（主要/次要/破坏性）的配色、触控与加载行为：
/// loading 时 label 不丢、旁置 ProgressView；内部 300ms 防连点；
/// disabled 走 disabled 色组且无操作；pressed 反馈遵循主题色组，
/// 主按钮 pressed 保持 accent 底与主按钮文字色，仅边界变化。
import SwiftUI

/// 按钮语义种类，决定配色来源。
enum AppButtonKind {
    /// 主要操作：buttonPrimary 色组。
    case primary
    /// 次要操作：buttonSecondary 色组。
    case secondary
    /// 破坏性操作：error 色组。
    case destructive
}


/// 卡片与按钮共用的按压反馈样式：按下时换色并做过渡动画。
struct PressFeedbackStyle: ButtonStyle {
    let background: Color
    let foreground: Color
    let border: Color
    let cornerRadius: CGFloat
    let pressedBackground: Color
    let pressedForeground: Color
    let pressedBorder: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(configuration.isPressed ? pressedForeground : foreground)
            .background(configuration.isPressed ? pressedBackground : background)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(configuration.isPressed ? pressedBorder : border, lineWidth: 1)
            )
            .animation(.easeInOut(duration: AppLayout.clickAnimation), value: configuration.isPressed)
    }
}


/// 稳定合同的共用按钮。
/// 输入为标题、kind、loading、enabled；输出为 action 回调（已内置防连点）。
/// 读屏焦点落在按钮上时绘制 focusBorder 外环，作为键盘/读屏焦点样式钩子。
struct AppButton: View {
    /// 两次触发之间的最小间隔，防止儿童连点造成重复提交。
    private static let debounceInterval: TimeInterval = 0.3

    @Environment(\.theme) private var theme
    @AccessibilityFocusState private var isAccessibilityFocused: Bool
    @State private var lastTrigger: Date = .distantPast

    private let title: String
    private let kind: AppButtonKind
    private let isLoading: Bool
    private let isEnabled: Bool
    private let action: () -> Void

    /// 创建按钮。action 已内置防连点节流，调用方无需再处理。
    init(
        _ title: String,
        kind: AppButtonKind = .primary,
        isLoading: Bool = false,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.kind = kind
        self.isLoading = isLoading
        self.isEnabled = isEnabled
        self.action = action
    }

    var body: some View {
        Button(action: trigger) {
            HStack(spacing: AppSpacing.xSmall) {
                if isLoading {
                    ProgressView()
                        .tint(colors.foreground)
                }
                Text(title)
                    .font(AppFont.body)
            }
            .frame(maxWidth: .infinity, minHeight: AppLayout.minTouchTarget)
        }
        .buttonStyle(pressStyle)
        .disabled(!isEnabled)
        .overlay(focusRing)
        .accessibilityLabel(title)
        .accessibilityHint(isLoading ? "正在处理，请稍候" : "")
        .accessibilityFocused($isAccessibilityFocused)
    }

    private var colors: (background: Color, foreground: Color, border: Color) {
        guard isEnabled else {
            return (theme.disabledBackground, theme.disabledForeground, theme.disabledBorder)
        }
        switch kind {
        case .primary:
            return (theme.buttonPrimaryBackground, theme.buttonPrimaryForeground, theme.buttonPrimaryBorder)
        case .secondary:
            return (theme.buttonSecondaryBackground, theme.buttonSecondaryForeground, theme.buttonSecondaryBorder)
        case .destructive:
            return (theme.error.background, theme.error.foreground, theme.error.foreground)
        }
    }

    private var pressedColors: (background: Color, foreground: Color, border: Color) {
        switch kind {
        case .primary:
            /* 主按钮 pressed 保持 accent 底与主按钮文字色，仅边界变化。 */
            return (theme.buttonPrimaryBackground, theme.buttonPrimaryForeground, theme.pressedBorder)
        case .secondary, .destructive:
            return (theme.pressedBackground, theme.pressedForeground, theme.pressedBorder)
        }
    }

    private var pressStyle: PressFeedbackStyle {
        PressFeedbackStyle(
            background: colors.background,
            foreground: colors.foreground,
            border: colors.border,
            cornerRadius: AppRadius.button,
            pressedBackground: pressedColors.background,
            pressedForeground: pressedColors.foreground,
            pressedBorder: pressedColors.border
        )
    }

    @ViewBuilder
    private var focusRing: some View {
        if isAccessibilityFocused {
            RoundedRectangle(cornerRadius: AppRadius.button)
                .stroke(theme.focusBorder, lineWidth: 2)
        }
    }

    private func trigger() {
        guard isEnabled, !isLoading else { return }
        let now = Date()
        guard now.timeIntervalSince(lastTrigger) >= Self.debounceInterval else { return }
        lastTrigger = now
        action()
    }
}


#Preview {
    VStack(spacing: AppSpacing.medium) {
        AppButton("主要按钮") {}
        AppButton("次要按钮", kind: .secondary) {}
        AppButton("删除记录", kind: .destructive) {}
        AppButton("提交中", isLoading: true) {}
        AppButton("暂不可用", isEnabled: false) {}
    }
    .padding(AppSpacing.medium)
}
