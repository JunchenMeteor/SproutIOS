/// 主题设置页。
/// 配色组五选一（每组给出浅色/深色真实 accent/page 预览色块）、明暗模式三选一；
/// 选择即写入 ThemeStore（UserDefaults，仅本设备），已打开弹层经环境注入即时生效。
import SwiftUI

struct ThemeSettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.theme) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                groupSection
                modeSection
                Text("主题只保存在这台设备。")
                    .font(AppFont.helper)
                    .foregroundStyle(theme.textSecondary)
            }
            .padding(AppSpacing.medium)
        }
        .frame(maxWidth: AppLayout.readingMaxWidth)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.page)
        .navigationTitle("主题设置")
    }

    private var groupSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            Text("配色组")
                .font(AppFont.section)
                .foregroundStyle(theme.textPrimary)
            ForEach(ThemeGroup.allCases, id: \.self) { group in
                groupRow(group)
            }
        }
    }

    private var modeSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            Text("明暗模式")
                .font(AppFont.section)
                .foregroundStyle(theme.textPrimary)
            ForEach(ThemeMode.allCases, id: \.self) { mode in
                modeRow(mode)
            }
        }
    }

    private func groupRow(_ group: ThemeGroup) -> some View {
        Button {
            environment.themeStore.setGroup(group)
        } label: {
            HStack(spacing: AppSpacing.small) {
                Text(groupName(group))
                    .font(AppFont.body)
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                swatches(for: group)
                checkmark(selected: environment.themeStore.group == group)
            }
            .padding(AppSpacing.small)
            .frame(minHeight: AppLayout.minTouchTarget)
            .background(theme.card)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
        }
        .buttonStyle(.plain)
    }

    private func modeRow(_ mode: ThemeMode) -> some View {
        Button {
            environment.themeStore.setMode(mode)
        } label: {
            HStack {
                Text(modeName(mode))
                    .font(AppFont.body)
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                checkmark(selected: environment.themeStore.mode == mode)
            }
            .padding(AppSpacing.small)
            .frame(minHeight: AppLayout.minTouchTarget)
            .background(theme.card)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
        }
        .buttonStyle(.plain)
    }

    private func swatches(for group: ThemeGroup) -> some View {
        HStack(spacing: AppSpacing.xxSmall) {
            swatch(ThemeFactory.makeTheme(group: group, dark: false))
            swatch(ThemeFactory.makeTheme(group: group, dark: true))
        }
    }

    private func swatch(_ tokens: ThemeTokens) -> some View {
        RoundedRectangle(cornerRadius: AppSpacing.xxSmall)
            .fill(tokens.page)
            .overlay {
                Circle()
                    .fill(tokens.accent)
                    .padding(AppSpacing.xSmall)
            }
            .overlay {
                RoundedRectangle(cornerRadius: AppSpacing.xxSmall)
                    .stroke(theme.border, lineWidth: 1)
            }
            .frame(width: AppSpacing.xLarge, height: AppSpacing.xLarge)
    }

    @ViewBuilder
    private func checkmark(selected: Bool) -> some View {
        if selected {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(theme.iconPrimary)
        } else {
            Image(systemName: "circle")
                .foregroundStyle(theme.iconTertiary)
        }
    }

    private func groupName(_ group: ThemeGroup) -> String {
        switch group {
        case .sky: return "晴空蓝"
        case .mist: return "雾蓝晨光"
        case .lavender: return "薰衣草"
        case .peach: return "蜜桃奶油"
        case .lemon: return "柠檬晴日"
        }
    }

    private func modeName(_ mode: ThemeMode) -> String {
        switch mode {
        case .system: return "跟随系统"
        case .light: return "浅色"
        case .dark: return "深色"
        }
    }
}
