/// 通用卡片容器。
/// 统一卡面背景、card 圆角、1pt 描边与轻投影；
/// isTappable 区分点击态：点击态提供 pressed 反馈并声明按钮无障碍特征。
/// 默认不限宽，页面需要限宽时经 maxWidth 传入 AppLayout.readingMaxWidth。
import SwiftUI

/// 卡片容器视图。
struct CardContainer<Content: View>: View {
    @Environment(\.theme) private var theme

    private let padding: CGFloat
    private let maxWidth: CGFloat?
    private let isTappable: Bool
    private let onTap: (() -> Void)?
    private let content: Content

    /// 创建卡片。isTappable 为 true 且提供 onTap 时，整张卡片表现为一个按钮。
    init(
        padding: CGFloat = AppSpacing.medium,
        maxWidth: CGFloat? = nil,
        isTappable: Bool = false,
        onTap: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.maxWidth = maxWidth
        self.isTappable = isTappable
        self.onTap = onTap
        self.content = content()
    }

    var body: some View {
        Group {
            if isTappable, let onTap {
                Button(action: onTap) {
                    cardBody
                }
                .buttonStyle(pressStyle)
                .accessibilityAddTraits(.isButton)
            } else {
                cardBody
            }
        }
    }

    private var cardBody: some View {
        content
            .padding(padding)
            .frame(maxWidth: maxWidth)
            .background(theme.card)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.card)
                    .stroke(theme.border, lineWidth: 1)
            )
            .shadow(color: theme.shadow, radius: AppSpacing.xSmall, y: AppSpacing.xxSmall)
    }

    private var pressStyle: CardPressStyle {
        CardPressStyle(pressedBorder: theme.pressedBorder)
    }
}


/// 卡片按压反馈：规范允许的轻缩放 0.98 加 pressed 描边，不遮蔽内容。
/// 组件库内部共享，供 CardContainer 与 RewardCard 复用。
struct CardPressStyle: ButtonStyle {
    /// 按下时的缩放系数（规范给定值）。
    private static let pressedScale: CGFloat = 0.98

    let pressedBorder: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? Self.pressedScale : 1)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.card)
                    .stroke(configuration.isPressed ? pressedBorder : .clear, lineWidth: 1)
            )
            .animation(.easeInOut(duration: AppLayout.clickAnimation), value: configuration.isPressed)
    }
}


#Preview {
    VStack(spacing: AppSpacing.medium) {
        CardContainer {
            Text("纯展示卡片")
                .font(AppFont.body)
        }
        CardContainer(isTappable: true, onTap: {}) {
            Text("可点击卡片")
                .font(AppFont.body)
        }
    }
    .padding(AppSpacing.medium)
}
