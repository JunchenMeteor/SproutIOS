/// 今日入口视图模型。
/// 负责 bootstrap 与课程进度加载、三种日模式选择与新课家长确认后创建计划；
/// 计划创建成功后写入本机快照，同日不反复换基础题。
import Foundation


/// 今日页状态与动作。后端与本机存储由 AppEnvironment 注入。
@Observable
@MainActor
final class TodayViewModel {
    private let backend: any BackendService
    private let localStore: LocalStore

    private(set) var isLoading = false
    private(set) var plan: Plan?
    private(set) var errorMessage: String?
    private(set) var suggestedNextLessonId: String?
    var toast: ToastMessage?
    private(set) var isOfflineSaved = false
    private(set) var selectedDayMode: DayMode?
    private(set) var isCreatingPlan = false
    /// 家长可修改的建议下一课课次。
    var editedNewLessonId = ""
    private var childId: String?
    private var progressRevision = 0
    private var timeZone: TimeZone = .current

    init(backend: any BackendService, localStore: LocalStore) {
        self.backend = backend
        self.localStore = localStore
    }

    /// 加载 bootstrap、课程进度与今日已存在计划的本机快照；已有计划直接展示。
    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let bootstrap = try await backend.bootstrap()
            timeZone = TimeZone(identifier: bootstrap.configuration.timezone) ?? .current
            guard let child = bootstrap.children.first else {
                errorMessage = "请先完成家长设置"
                return
            }
            childId = child.id
            let progress = try await backend.fetchProgress(childId: child.id)
            progressRevision = progress.revision
            suggestedNextLessonId = String(progress.confirmedLessonIds.count + 1)
            editedNewLessonId = suggestedNextLessonId ?? ""
            plan = restoredTodayPlan(childId: child.id)
        } catch let error as BackendError {
            errorMessage = Self.errorText(for: error)
        } catch {
            errorMessage = "加载失败，请稍后重试"
        }
    }

    /// 选择日模式。新课仅进入待确认状态，家长确认后才创建计划推进进度。
    func selectDayMode(_ mode: DayMode) {
        selectedDayMode = mode
        switch mode {
        case .new:
            break
        case .review, .unknown:
            Task { await createPlanFlow(mode: mode, confirmedNewLessonId: nil) }
        }
    }

    /// 家长确认或修改建议课次后创建新课计划；复习与未知不推进课程进度。
    func confirmNewLessonAndCreatePlan() {
        let trimmed = editedNewLessonId.trimmingCharacters(in: .whitespacesAndNewlines)
        let confirmed = trimmed.isEmpty ? suggestedNextLessonId : trimmed
        guard let confirmedNewLessonId = confirmed, !confirmedNewLessonId.isEmpty else {
            toast = ToastMessage(semantic: .warning, text: "请先填写或确认下一课")
            return
        }
        Task { await createPlanFlow(mode: .new, confirmedNewLessonId: confirmedNewLessonId) }
    }

    /* 创建计划成功后写入本机快照；冲突与版本错误映射为中文提示。 */
    private func createPlanFlow(mode: DayMode, confirmedNewLessonId: String?) async {
        guard !isCreatingPlan, let childId else { return }
        isCreatingPlan = true
        defer { isCreatingPlan = false }
        do {
            let created = try await backend.createPlan(
                childId: childId,
                targetDate: .today(timeZone: timeZone),
                dayMode: mode,
                expectedProgressRevision: progressRevision,
                confirmedNewLessonId: confirmedNewLessonId
            )
            plan = created
            progressRevision = created.progressRevision
            saveSnapshot(created, childId: childId)
        } catch let error as BackendError {
            handlePlanError(error)
        } catch {
            toast = ToastMessage(semantic: .error, text: "创建计划失败，请稍后重试")
        }
    }

    /* 快照的 itemsJSON 承载完整 Plan 编码（存储层不做强类型解析），读取失败视为无计划。 */
    private func restoredTodayPlan(childId: String) -> Plan? {
        let today = BusinessDate.today(timeZone: timeZone)
        guard let snapshot = localStore.planSnapshot(childId: childId, targetDate: today.rawValue) else {
            return nil
        }
        do {
            return try ContractJSON.makeDecoder().decode(Plan.self, from: snapshot.itemsJSON)
        } catch {
            return nil
        }
    }

    /* 快照承载完整 Plan 编码，保证再次进入时条目与 revision 完整；失败仅提示不阻断。 */
    private func saveSnapshot(_ plan: Plan, childId: String) {
        do {
            let data = try ContractJSON.makeEncoder().encode(plan)
            let snapshot = LocalPlanSnapshot(
                planId: plan.id,
                targetDate: plan.targetDate.rawValue,
                dayMode: plan.dayMode.rawValue,
                contentVersion: plan.contentVersion,
                itemsJSON: data
            )
            try localStore.savePlanSnapshot(snapshot, childId: childId, targetDate: plan.targetDate.rawValue)
        } catch {
            toast = ToastMessage(semantic: .warning, text: "本机快照保存失败，刷新后可恢复")
        }
    }

    private func handlePlanError(_ error: BackendError) {
        switch error {
        case .offline:
            isOfflineSaved = true
            toast = ToastMessage(semantic: .info, text: "当前离线，已保存本机进度，联网后确认")
        case .planConflict:
            toast = ToastMessage(semantic: .info, text: "今天已有计划，正在为你加载")
            Task { await load() }
        case .versionConflict:
            toast = ToastMessage(semantic: .warning, text: "进度在其他设备被修改，请刷新")
        default:
            toast = ToastMessage(semantic: .error, text: "创建计划失败，请稍后重试")
        }
    }

    private static func errorText(for error: BackendError) -> String {
        switch error {
        case .offline:
            return "当前离线，联网后自动同步"
        case .versionConflict:
            return "进度在其他设备被修改，请刷新"
        default:
            return "加载失败，请检查网络后重试"
        }
    }
}
