/// 顶部横幅提示（toast）。
/// 提供 ToastMessage 消息模型与 toastBanner 修饰器：不透明 elevated 底，
/// 文字与图标走对应 StatusColors；非 error 自动消失，error 持续展示并给关闭按钮；
/// 出现时向读屏发出公告；颜色全部消费主题环境，主题切换即时生效。
import SwiftUI

/// 横幅语义，决定状态色组与图标。
enum ToastSemantic {
    case success
    case warning
    case error
    case info
}


/// 一条待展示的横幅消息。
/// error 语义默认 duration 为 nil，表示持续展示、需手动关闭。
/// 相等性只看 id，回调不参与比较。
struct ToastMessage: Identifiable, Equatable {
    let id: UUID
    let semantic: ToastSemantic
    let text: String
    /// 可选操作按钮标题；与 onAction 同时提供才显示。
    let actionTitle: String?
    /// 自动消失时长；nil 表示不自动消失。
    let duration: TimeInterval?
    let onAction: (() -> Void)?

    init(
        id: UUID = UUID(),
        semantic: ToastSemantic,
        text: String,
        actionTitle: String? = nil,
        duration: TimeInterval? = nil,
        onAction: (() -> Void)? = nil
    ) {
        self.id = id
        self.semantic = semantic
        self.text = text
        self.actionTitle = actionTitle
        self.duration = duration
        self.onAction = onAction
    }

    static func == (lhs: ToastMessage, rhs: ToastMessage) -> Bool {
        lhs.id == rhs.id
    }
}


/// 横幅宿主修饰器：绑定为 nil 时不展示，非 nil 时在顶部安全区内展示。
private struct ToastBannerModifier: ViewModifier {
    /// 非 error 消息的默认展示时长（秒）。
    private static let defaultDuration: TimeInterval = 3

    @Environment(\.theme) private var theme
    @Binding var message: ToastMessage?
    @State private var dismissGeneration = 0

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .top, spacing: AppSpacing.xSmall) {
                banner
            }
            .animation(.easeInOut(duration: AppLayout.transitionAnimation), value: message != nil)
            .onChange(of: message) { _, newValue in
                handleChange(newValue)
            }
    }

    @ViewBuilder
    private var banner: some View {
        if let message {
            HStack(spacing: AppSpacing.small) {
                Image(systemName: iconName(for: message.semantic))
                    .foregroundStyle(statusColors(for: message.semantic).icon)
                Text(message.text)
                    .font(AppFont.helper)
                    .foregroundStyle(statusColors(for: message.semantic).foreground)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                trailingItems(for: message)
            }
            .padding(AppSpacing.small)
            .background(theme.elevated)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.button)
                    .stroke(theme.border, lineWidth: 1)
            )
            .shadow(color: theme.shadow, radius: AppSpacing.xSmall, y: AppSpacing.xxSmall)
            .padding(.horizontal, AppSpacing.medium)
        }
    }

    @ViewBuilder
    private func trailingItems(for message: ToastMessage) -> some View {
        if let actionTitle = message.actionTitle, let onAction = message.onAction {
            Button(actionTitle) {
                onAction()
                dismiss()
            }
            .font(AppFont.helper)
            .foregroundStyle(theme.link)
        }
        if message.semantic == .error {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(theme.iconSecondary)
            }
            .frame(minWidth: AppLayout.minTouchTarget, minHeight: AppLayout.minTouchTarget)
            .accessibilityLabel("关闭提示")
        }
    }

    private func statusColors(for semantic: ToastSemantic) -> StatusColors {
        switch semantic {
        case .success: return theme.success
        case .warning: return theme.warning
        case .error: return theme.error
        case .info: return theme.info
        }
    }

    private func iconName(for semantic: ToastSemantic) -> String {
        switch semantic {
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.octagon.fill"
        case .info: return "info.circle.fill"
        }
    }

    private func dismiss() {
        dismissGeneration += 1
        message = nil
    }

    /*
     消息出现时：代次加一使旧定时失效、向读屏公告文案，
     非 error 且未指定时长时按默认时长调度自动消失。
     定时回调只认最新代次，避免旧消息关闭新消息。
     */
    private func handleChange(_ newValue: ToastMessage?) {
        dismissGeneration += 1
        guard let newValue else { return }
        AccessibilityNotification.Announcement(newValue.text).post()
        let duration = newValue.duration ?? (newValue.semantic == .error ? nil : Self.defaultDuration)
        guard let duration else { return }
        let generation = dismissGeneration
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            guard generation == dismissGeneration else { return }
            message = nil
        }
    }
}


extension View {
    /// 在视图顶部挂载横幅提示；message 为 nil 时不展示。
    /// 横幅出现在安全区内，不遮挡状态栏，也不会顶出页面内容之外。
    func toastBanner(_ message: Binding<ToastMessage?>) -> some View {
        modifier(ToastBannerModifier(message: message))
    }
}


#Preview {
    struct PreviewHost: View {
        @State private var message: ToastMessage? = ToastMessage(
            semantic: .success,
            text: "打卡成功，继续保持"
        )

        var body: some View {
            VStack(spacing: AppSpacing.medium) {
                AppButton("显示错误提示", kind: .secondary) {
                    message = ToastMessage(semantic: .error, text: "网络异常，请稍后重试")
                }
                AppButton("显示警告提示", kind: .secondary) {
                    message = ToastMessage(semantic: .warning, text: "今天还没有打卡")
                }
            }
            .padding(AppSpacing.medium)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .toastBanner($message)
        }
    }
    return PreviewHost()
}
