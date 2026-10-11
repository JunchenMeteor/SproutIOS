/// 家长管理页。
/// 入口列表按 CardContainer 分组：儿童档案摘要、主题设置、录音与数据说明、
/// 导出/备份与删除数据（首版禁用并标注等待真实后端）、切换账号/退出（二次确认）、
/// 版本信息。页面只组合 ParentViewModel 与组件；档案统计当前为模拟服务来源。
import SwiftUI

struct ParentView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.theme) private var theme
    @State private var viewModel: ParentViewModel?
    @State private var showSignOutConfirm = false
    @State private var toast: ToastMessage?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.medium) {
                    guardianNote
                    if let viewModel {
                        ProfileSection(viewModel: viewModel)
                        themeEntry
                        DataPolicySection()
                        dataActions
                        signOutSection
                        VersionSection(isMockBackend: environment.isMockBackend)
                    } else {
                        ProgressView("加载中…")
                            .padding(AppSpacing.xLarge)
                    }
                }
                .padding(AppSpacing.medium)
            }
            .frame(maxWidth: AppLayout.readingMaxWidth)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.page)
            .navigationTitle("家长")
        }
        .task { await prepareIfNeeded() }
        .confirmationDialog("切换账号 / 退出登录",
                            isPresented: $showSignOutConfirm, titleVisibility: .visible) {
            Button("退出登录", role: .destructive) {
                viewModel?.signOut()
                toast = ToastMessage(semantic: .success, text: "已退出登录；待同步数据仍保留在本机")
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("只清除本机会话令牌，待同步数据仍保留在本机")
        }
        .toastBanner($toast)
    }

    private var guardianNote: some View {
        Text("以下操作仅供家长")
            .font(AppFont.helper)
            .foregroundStyle(theme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var themeEntry: some View {
        NavigationLink {
            ThemeSettingsView()
        } label: {
            HStack {
                Text("主题设置")
                    .font(AppFont.body)
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(theme.iconTertiary)
            }
            .padding(AppSpacing.medium)
            .frame(minHeight: AppLayout.minTouchTarget)
            .background(theme.card)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        }
    }

    private var dataActions: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: AppSpacing.small) {
                AppButton("导出 / 备份数据", kind: .secondary, isLoading: false, isEnabled: false) {}
                Text("即将推出：等待真实后端")
                    .font(AppFont.helper)
                    .foregroundStyle(theme.textTertiary)
                AppButton("删除全部数据", kind: .destructive, isLoading: false, isEnabled: false) {}
                Text("删除将清除云端与本机的打卡记录和录音，不可恢复；首版暂未开放")
                    .font(AppFont.helper)
                    .foregroundStyle(theme.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var signOutSection: some View {
        AppButton("切换账号 / 退出登录", kind: .secondary, isLoading: false, isEnabled: true) {
            showSignOutConfirm = true
        }
    }

    private func prepareIfNeeded() async {
        guard viewModel == nil else { return }
        let model = ParentViewModel(backend: environment.backend, localStore: environment.localStore)
        viewModel = model
        await model.load()
    }
}


/// 儿童档案摘要分组：昵称来自 bootstrap，教材/课次/录音保留策略来自本机草稿。
private struct ProfileSection: View {
    @Environment(\.theme) private var theme
    let viewModel: ParentViewModel

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                sectionTitle("当前儿童")
                infoRow(title: "昵称", value: viewModel.childName ?? "未设置")
                infoRow(title: "教材", value: viewModel.courseEditionId ?? "未设置")
                infoRow(title: "课次", value: viewModel.currentLessonId ?? "未设置")
                infoRow(title: "录音保留", value: retentionText)
                if let message = viewModel.errorMessage {
                    Text(message)
                        .font(AppFont.helper)
                        .foregroundStyle(theme.error.foreground)
                }
                Text("连续/累计统计待真实统计接口提供（当前为模拟服务）")
                    .font(AppFont.helper)
                    .foregroundStyle(theme.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var retentionText: String {
        guard let retain = viewModel.retainRecordings else { return "未设置" }
        return retain ? "长期保留（家长已选择）" : "评测完成后不长期保留"
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(AppFont.section)
            .foregroundStyle(theme.textPrimary)
    }

    private func infoRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(AppFont.helper)
                .foregroundStyle(theme.textSecondary)
            Spacer()
            Text(value)
                .font(AppFont.body)
                .foregroundStyle(theme.textPrimary)
        }
    }
}


/// 录音与数据说明分组：云端发送与删除政策的静态文案展示。
private struct DataPolicySection: View {
    @Environment(\.theme) private var theme

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text("录音与数据说明")
                    .font(AppFont.section)
                    .foregroundStyle(theme.textPrimary)
                Text("录音仅用于本次口语评测，随打卡提交发送至云端；"
                     + "本机录音按保留策略到期自动删除，云端数据可申请删除。")
                    .font(AppFont.helper)
                    .foregroundStyle(theme.textSecondary)
                Text("当前为模拟服务，不会真实上传任何录音")
                    .font(AppFont.helper)
                    .foregroundStyle(theme.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}


/// 版本信息分组：应用版本、契约版本与模拟服务标注。
private struct VersionSection: View {
    @Environment(\.theme) private var theme
    let isMockBackend: Bool

    var body: some View {
        VStack(spacing: AppSpacing.xxSmall) {
            Text("版本 \(appVersion)（\(appBuild)）")
            Text("契约版本 EC-API-0.1")
            Text(isMockBackend ? "当前数据来源：模拟服务" : "当前数据来源：真实后端")
        }
        .font(AppFont.helper)
        .foregroundStyle(theme.textTertiary)
        .frame(maxWidth: .infinity)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }
}
