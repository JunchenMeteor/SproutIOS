/// Debug 模拟服务常驻横幅。
/// 仅 DEBUG 构建渲染，提示当前数据来自本机演示、不代表真实云端评测；
/// Release 构建中编译为空视图，零开销。读屏可获取完整说明。
import SwiftUI

/// 模拟服务提示横幅。页面在 Debug 模拟模式下置于顶部常驻展示。
struct MockServiceBanner: View {
    @Environment(\.theme) private var theme

    var body: some View {
        #if DEBUG
        HStack(spacing: AppSpacing.xSmall) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(theme.info.icon)
            Text("模拟服务：数据来自本机演示，不代表真实云端评测")
                .font(AppFont.helper)
                .foregroundStyle(theme.info.foreground)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(AppSpacing.small)
        .background(theme.info.background)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("模拟服务：数据来自本机演示，不代表真实云端评测")
        #else
        EmptyView()
        #endif
    }
}


#Preview {
    MockServiceBanner()
}
