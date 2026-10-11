/// 统一弹层封装。
/// 提供 appSheet 修饰器：elevated 背景、sheet 圆角、section 字标题栏与关闭按钮；
/// 内容放在 ScrollView 中以避让键盘并支持交互式下滑收起键盘，内容限宽 readingMaxWidth。
/// 焦点恢复说明：sheet 收起时系统自动把读屏/键盘焦点交还唤起页面；
/// 若页面用 FocusState 管理输入焦点，需在 onDismiss 中显式复位。
import SwiftUI

/// 弹层关闭策略。
enum AppSheetClosePolicy {
    /// 下滑手势与关闭按钮均可关闭。
    case swipeAndButton
    /// 仅允许点击关闭按钮，防止误滑丢失进行中的操作。
    case buttonOnly
}


/// 弹层内容容器：标题栏 + 可滚动内容区。
private struct AppSheetContainer<Content: View>: View {
    @Environment(\.theme) private var theme

    let title: String
    let closePolicy: AppSheetClosePolicy
    @Binding var isPresented: Bool
    let content: Content

    var body: some View {
        VStack(spacing: AppSpacing.xSmall) {
            titleBar
            ScrollView {
                content
                    .padding(AppSpacing.medium)
                    .frame(maxWidth: AppLayout.readingMaxWidth)
                    .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(theme.elevated)
        .presentationBackground(theme.elevated)
        .presentationCornerRadius(AppRadius.sheet)
        .interactiveDismissDisabled(closePolicy == .buttonOnly)
    }

    private var titleBar: some View {
        HStack {
            Text(title)
                .font(AppFont.section)
                .foregroundStyle(theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                isPresented = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(AppFont.section)
                    .foregroundStyle(theme.iconSecondary)
            }
            .frame(minWidth: AppLayout.minTouchTarget, minHeight: AppLayout.minTouchTarget)
            .accessibilityLabel("关闭")
        }
        .padding(.horizontal, AppSpacing.medium)
        .padding(.top, AppSpacing.medium)
    }
}


extension View {
    /// 以统一样式弹出 sheet。
    /// closePolicy 决定关闭途径；onDismiss 在 sheet 完全收起后回调，
    /// 页面可在此恢复焦点或提交结果。
    func appSheet<Content: View>(
        isPresented: Binding<Bool>,
        title: String,
        closePolicy: AppSheetClosePolicy = .swipeAndButton,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        sheet(isPresented: isPresented, onDismiss: onDismiss) {
            AppSheetContainer(
                title: title,
                closePolicy: closePolicy,
                isPresented: isPresented,
                content: content()
            )
        }
    }
}


#Preview {
    struct PreviewHost: View {
        @State private var isPresented = true

        var body: some View {
            AppButton("打开弹层") {
                isPresented = true
            }
            .appSheet(isPresented: $isPresented, title: "设置") {
                Text("这里是弹层内容，超宽屏幕下最多 720pt 宽。")
                    .font(AppFont.body)
            }
        }
    }
    return PreviewHost()
}
