/// 家长首次设置页与视图模型。
/// 首次启动由家长填写儿童昵称、选择教材版本与已学课次、决定是否长期保留录音；
/// 完成后写入本机草稿并标记 onboarding 完成，页面不含网络与存储细节。
import SwiftUI


/// 家长设置页状态与动作。教材列表经后端拉取，草稿写入本机存储。
@Observable
@MainActor
final class ParentSetupViewModel {
    private let backend: any BackendService
    private let localStore: LocalStore

    var nickname = ""
    var selectedCourseEditionId: String?
    var currentLessonIndex = 0
    var keepRecordingsLongTerm = false
    var nicknameError: String?
    private(set) var formError: String?
    private(set) var courseEditions: [CourseEditionSummary] = []
    private(set) var isLoading = false
    private(set) var isSaving = false
    private(set) var loadErrorMessage: String?

    init(backend: any BackendService, localStore: LocalStore) {
        self.backend = backend
        self.localStore = localStore
    }

    /// 拉取教材版本列表；失败保留错误文案，由页面提供重试。
    func loadCourses() async {
        isLoading = true
        loadErrorMessage = nil
        defer { isLoading = false }
        do {
            let editions = try await backend.fetchCourses()
            courseEditions = editions
            if selectedCourseEditionId == nil {
                selectedCourseEditionId = editions.first?.id
            }
        } catch {
            loadErrorMessage = "教材列表加载失败，请检查网络后重试"
        }
    }

    /// 校验昵称与教材并保存草稿，随后标记首次设置完成；返回是否成功。
    func complete() -> Bool {
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            nicknameError = "请填写孩子昵称"
            return false
        }
        guard let courseEditionId = selectedCourseEditionId else {
            formError = "请选择教材版本"
            return false
        }
        nicknameError = nil
        formError = nil
        isSaving = true
        defer { isSaving = false }
        let draft = ChildProfileDraft(
            nickname: trimmed,
            courseEditionId: courseEditionId,
            currentLessonId: currentLessonIndex > 0 ? String(currentLessonIndex) : nil,
            retainRecordings: keepRecordingsLongTerm
        )
        do {
            try localStore.saveChildProfileDraft(draft)
            try localStore.setOnboardingCompleted(true)
            return true
        } catch {
            formError = "保存失败，请重试"
            return false
        }
    }
}


/// 家长首次设置页。仅组合视图模型与组件，网络与存储细节在视图模型与服务层。
struct ParentSetupView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.theme) private var theme
    @State private var viewModel: ParentSetupViewModel?

    /// 完成回调，由根容器切换到今日页。
    let onCompleted: () -> Void

    init(onCompleted: @escaping () -> Void = {}) {
        self.onCompleted = onCompleted
    }

    var body: some View {
        Group {
            if let viewModel {
                formContent(viewModel: viewModel)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(theme.page)
        .navigationTitle("家长设置")
        .task { await prepareViewModel() }
    }

    private func prepareViewModel() async {
        guard viewModel == nil else { return }
        let created = ParentSetupViewModel(backend: environment.backend, localStore: environment.localStore)
        viewModel = created
        await created.loadCourses()
    }

    private func formContent(viewModel: ParentSetupViewModel) -> some View {
        @Bindable var bindable = viewModel
        return ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                headerSection
                AppFormField(
                    label: "孩子昵称",
                    text: $bindable.nickname,
                    placeholder: "请输入昵称",
                    isRequired: true,
                    error: viewModel.nicknameError
                )
                courseSection(viewModel: viewModel)
                lessonSection(selection: $bindable.currentLessonIndex)
                recordingSection(isOn: $bindable.keepRecordingsLongTerm)
                if let formError = viewModel.formError {
                    Text(formError)
                        .font(AppFont.helper)
                        .foregroundStyle(theme.error.foreground)
                }
                AppButton("完成", isLoading: viewModel.isSaving) {
                    if viewModel.complete() { onCompleted() }
                }
            }
            .padding(AppSpacing.large)
            .frame(maxWidth: AppLayout.readingMaxWidth)
            .frame(maxWidth: .infinity)
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
            Label("家长操作", systemImage: "person.badge.shield.checkmark")
                .font(AppFont.section)
                .foregroundStyle(theme.textPrimary)
            Text("本页设置仅由家长填写，孩子日常练习不会看到。")
                .font(AppFont.helper)
                .foregroundStyle(theme.textSecondary)
        }
    }

    private func courseSection(viewModel: ParentSetupViewModel) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            Text("教材版本")
                .font(AppFont.section)
                .foregroundStyle(theme.textPrimary)
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if let message = viewModel.loadErrorMessage {
                errorRow(message: message) {
                    Task { await viewModel.loadCourses() }
                }
            } else {
                ForEach(viewModel.courseEditions, id: \.id) { edition in
                    courseRow(viewModel: viewModel, edition: edition)
                }
            }
        }
    }

    /* 未获许可或模拟服务的教材明确标注原创演示，不冒充课本。 */
    private func courseRow(viewModel: ParentSetupViewModel, edition: CourseEditionSummary) -> some View {
        let isSelected = viewModel.selectedCourseEditionId == edition.id
        let isDemo = environment.isMockBackend || !edition.licensed
        return Button {
            viewModel.selectedCourseEditionId = edition.id
        } label: {
            HStack(spacing: AppSpacing.small) {
                VStack(alignment: .leading, spacing: AppSpacing.xxSmall) {
                    Text(edition.title)
                        .font(AppFont.body)
                        .foregroundStyle(theme.textPrimary)
                    Text(edition.publisherNote)
                        .font(AppFont.helper)
                        .foregroundStyle(theme.textSecondary)
                    if isDemo {
                        Text("原创演示教材，非课本内容")
                            .font(AppFont.helper)
                            .foregroundStyle(theme.warning.foreground)
                    }
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(theme.accent)
                }
            }
            .padding(AppSpacing.medium)
            .background(isSelected ? theme.selectionBackground : theme.card)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        }
        .buttonStyle(.plain)
    }

    private func lessonSection(selection: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
            Text("当前已学课次")
                .font(AppFont.section)
                .foregroundStyle(theme.textPrimary)
            Stepper("已学到第 \(selection.wrappedValue) 课", value: selection, in: 0 ... 200)
                .font(AppFont.body)
                .foregroundStyle(theme.textPrimary)
        }
    }

    private func recordingSection(isOn: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
            Toggle("长期保留孩子录音", isOn: isOn)
                .font(AppFont.body)
                .foregroundStyle(theme.textPrimary)
                .tint(theme.accent)
            Text("录音会发送到服务器与家长选择的语音服务商用于评测。默认不长期保留，评测完成后即删除。")
                .font(AppFont.helper)
                .foregroundStyle(theme.textSecondary)
        }
    }

    private func errorRow(message: String, onRetry: @escaping () -> Void) -> some View {
        HStack(spacing: AppSpacing.small) {
            Text(message)
                .font(AppFont.helper)
                .foregroundStyle(theme.error.foreground)
            Spacer()
            AppButton("重试", kind: .secondary, action: onRetry)
        }
    }
}
