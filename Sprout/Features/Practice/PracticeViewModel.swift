/// 练习流程视图模型。
/// 编排录音与播放互斥、上传与尝试创建、有界评测轮询与完成打卡；
/// 评测失败或离线不阻止打卡，离线打卡写入离线队列。
import CryptoKit
import Foundation


/// 离线打卡的队列载荷；契约未冻结期间以 JSON 透传，重放时按字段重建请求。
private struct PendingCheckInPayload: Codable {
    let childId: String
    let planId: String
    let targetDate: BusinessDate
    let clientCompletionId: UUID
    let clientCompletedAt: Date
    let planRevision: Int
    let itemOutcomes: [ItemOutcome]
}


/// 练习流程的后端调用集合：上传与建尝试、组装题目结果、打卡与离线入队。
private struct PracticeBackendGateway {
    let backend: any BackendService
    let offlineQueue: OfflineQueue

    /// 上传录音并创建尝试，返回尝试 id 与评测 job id（服务端未启动评测时为 nil）。
    /// 幂等键沿用 clientAttemptId，重试不产生重复尝试。
    func submit(plan: Plan, item: PlanItem, fileURL: URL,
        clientAttemptId: UUID) async throws -> (attemptId: String, jobId: String?) {
        let audio = try await backend.uploadAudio(childId: plan.childId, planId: plan.id, itemId: item.id,
            clientAttemptId: clientAttemptId, fileURL: fileURL, sha256: try Self.sha256Hex(of: fileURL),
            idempotencyKey: clientAttemptId.uuidString)
        let attempt = try await backend.createAttempt(clientAttemptId: clientAttemptId, planId: plan.id,
            itemId: item.id, audioId: audio.id, clientCompletedAt: Date(),
            idempotencyKey: clientAttemptId.uuidString)
        return (attempt.id, attempt.evaluationJobId)
    }

    /// 组装已处理题目的结果：跳过带原因，完成带云端或本机尝试 id。
    static func outcomes(plan: Plan, completed: Set<String>, skipped: [String: String],
        attemptIds: [String: String], localAttemptIds: [String: UUID]) -> [ItemOutcome] {
        plan.items.filter { completed.contains($0.id) || skipped[$0.id] != nil }.map { item in
            if let reason = skipped[item.id] {
                return ItemOutcome(itemId: item.id, outcome: .skipped, attemptId: nil,
                    localAttemptId: nil, skipReason: reason)
            }
            return ItemOutcome(itemId: item.id, outcome: .completed, attemptId: attemptIds[item.id],
                localAttemptId: localAttemptIds[item.id], skipReason: nil)
        }
    }

    /// 打卡；离线时写入离线队列并返回 nil，其他错误继续抛出。
    func checkIn(plan: Plan, outcomes: [ItemOutcome], completionId: UUID) async throws -> CheckInResult? {
        do {
            return try await backend.createCheckIn(childId: plan.childId, planId: plan.id,
                targetDate: plan.targetDate, clientCompletionId: completionId, clientCompletedAt: Date(),
                planRevision: plan.revision, itemOutcomes: outcomes, idempotencyKey: completionId.uuidString)
        } catch let error as BackendError {
            guard case .offline = error else { throw error }
            try enqueueCheckIn(plan: plan, outcomes: outcomes, completionId: completionId)
            return nil
        }
    }

    /* 离线打卡入队：操作 id 即完成 id，重放沿用同一 Idempotency-Key，不生成新业务 id。 */
    private func enqueueCheckIn(plan: Plan, outcomes: [ItemOutcome], completionId: UUID) throws {
        let payload = PendingCheckInPayload(childId: plan.childId, planId: plan.id,
            targetDate: plan.targetDate, clientCompletionId: completionId, clientCompletedAt: Date(),
            planRevision: plan.revision, itemOutcomes: outcomes)
        let operation = PendingOperation(id: completionId, kind: .checkIn,
            payloadJSON: try ContractJSON.makeEncoder().encode(payload), accountID: plan.childId)
        try offlineQueue.enqueue(operation)
    }

    private static func sha256Hex(of url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}


/// 练习页状态与动作。录音、播放、文件与后端服务由 AppEnvironment 注入。
@Observable
@MainActor
final class PracticeViewModel {
    private let plan: Plan
    private let recorder: AudioRecorderService
    private let player: AudioPlayerService
    private let recordingFiles: RecordingFileStore
    private let gateway: PracticeBackendGateway
    private let poller: EvaluationPoller

    private(set) var currentItemIndex = 0
    private(set) var isSubmitting = false
    private(set) var isCheckingIn = false
    private(set) var feedback = FeedbackContent.pending
    var isParentExpanded = false
    private(set) var completedItemIds: Set<String> = []
    private(set) var skipReasons: [String: String] = [:]
    var showCompletion = false
    var toast: ToastMessage?
    private(set) var isOfflineSaved = false
    private(set) var checkInResult: CheckInResult?
    private var attemptIds: [String: String] = [:]
    private var localAttemptIds: [String: UUID] = [:]

    init(plan: Plan, environment: AppEnvironment) {
        self.plan = plan
        recorder = environment.recorder
        player = environment.player
        recordingFiles = environment.recordingFiles
        gateway = PracticeBackendGateway(backend: environment.backend, offlineQueue: environment.offlineQueue)
        poller = EvaluationPoller(backend: environment.backend)
    }

    /// 当前题；下标越界时为 nil。
    var currentItem: PlanItem? {
        guard plan.items.indices.contains(currentItemIndex) else { return nil }
        return plan.items[currentItemIndex]
    }

    /// 录音控件状态，由录音机领域状态映射；录音中时长取实时秒数。
    var recorderControlState: RecorderControlState {
        switch recorder.state {
        case .idle, .confirmed:
            return .idle
        case .recording:
            return .recording(duration: recorder.elapsedSeconds)
        case .interrupted:
            return .interrupted
        case .recorded(_, let duration):
            return .recorded(duration: duration)
        case .queued, .uploading:
            return .uploading
        case .error(let message, _):
            return .failed(message: message)
        }
    }

    /// 仅 recorded 态可提交。
    var canSubmit: Bool {
        if case .recorded = recorder.state { return !isSubmitting }
        return false
    }

    /// 必做题全部完成或合法跳过即可打卡，与分数和评测结果无关。
    var canCheckIn: Bool {
        plan.completionPolicy.requiredItemIds.allSatisfy { isSettled($0) }
    }

    /// 录音前停播放；error 态先复位，recorded 态重录的旧片段由录音服务自行清理。
    func onRecord() {
        player.stop()
        if case .error = recorder.state {
            recorder.discardRecording()
        }
        recorder.startRecording()
    }

    func onStop() {
        recorder.stopRecording()
    }

    /// 仅在已有录音时可回放；录音与播放互斥由控件状态保证。
    func onPlay() {
        guard case .recorded(let fileID, _) = recorder.state else { return }
        guard let url = recordingFiles.url(for: fileID) else {
            toast = ToastMessage(semantic: .error, text: "找不到录音文件")
            return
        }
        player.play(url: url)
    }

    func onDiscard() {
        player.stop()
        recorder.discardRecording()
    }

    /// 提交当前题：上传、建尝试、轮询反馈；离线保留本机尝试，不挡打卡。
    func submitCurrentItem() async {
        guard !isSubmitting, let item = currentItem,
              case .recorded(let fileID, _) = recorder.state,
              let fileURL = recordingFiles.url(for: fileID) else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        let clientAttemptId = UUID()
        recorder.markQueued()
        recorder.markUploading()
        do {
            let result = try await gateway.submit(plan: plan, item: item, fileURL: fileURL,
                clientAttemptId: clientAttemptId)
            recorder.markConfirmed()
            attemptIds[item.id] = result.attemptId
            markSettled(item.id, localAttemptId: clientAttemptId)
            feedback = await pollFeedback(jobId: result.jobId)
        } catch let error as BackendError {
            handleSubmitFailure(error, item: item, clientAttemptId: clientAttemptId)
        } catch {
            recorder.markFailed("提交失败，请重试。")
            feedback = .requestFailed
        }
    }

    /* 服务端未启动评测任务时明确不确定，不填假分数。 */
    private func pollFeedback(jobId: String?) async -> FeedbackContent {
        guard let jobId else { return .timeout }
        return await poller.poll(jobId: jobId)
    }

    /* 离线：保留本机尝试并标记完成，反馈不确定，不挡打卡；其他失败可重试。 */
    private func handleSubmitFailure(_ error: BackendError, item: PlanItem, clientAttemptId: UUID) {
        recorder.markFailed(Self.errorText(for: error))
        guard case .offline = error else {
            feedback = .requestFailed
            toast = ToastMessage(semantic: .error, text: Self.errorText(for: error))
            return
        }
        markSettled(item.id, localAttemptId: clientAttemptId)
        feedback = .unclear
        isOfflineSaved = true
        toast = ToastMessage(semantic: .info, text: "当前离线，已保存本机进度，联网后确认")
    }

    /// 合规跳过：记录原因并前进到下一未处理题。
    func skipCurrentItem(reason: String) {
        guard let item = currentItem,
              plan.completionPolicy.allowedSkipReasons.contains(reason) else { return }
        resetRecorder()
        skipReasons[item.id] = reason
        feedback = .pending
        moveToNextUnsettledItem()
    }

    /// 反馈展示后进入下一未处理题。
    func goToNextItem() {
        feedback = .pending
        moveToNextUnsettledItem()
    }

    /// 组装题目结果并打卡；离线入队时标记本机已保存，其余失败给 toast。
    func completePlan() async {
        guard !isCheckingIn, canCheckIn else { return }
        isCheckingIn = true
        defer { isCheckingIn = false }
        let outcomes = PracticeBackendGateway.outcomes(plan: plan, completed: completedItemIds,
            skipped: skipReasons, attemptIds: attemptIds, localAttemptIds: localAttemptIds)
        do {
            let result = try await gateway.checkIn(plan: plan, outcomes: outcomes, completionId: UUID())
            isOfflineSaved = result == nil
            checkInResult = result
            showCompletion = true
        } catch let error as BackendError {
            toast = ToastMessage(semantic: .error, text: Self.errorText(for: error))
        } catch {
            toast = ToastMessage(semantic: .error, text: "打卡失败，请稍后重试")
        }
    }

    /// 「再玩一关」：关闭完成页并回到首个未处理题。
    func startExtraPractice() {
        showCompletion = false
        goToNextItem()
    }

    /// 题目是否已完成或合法跳过。
    func isSettled(_ itemId: String) -> Bool {
        completedItemIds.contains(itemId) || skipReasons[itemId] != nil
    }

    private func markSettled(_ itemId: String, localAttemptId: UUID) {
        completedItemIds.insert(itemId)
        localAttemptIds[itemId] = localAttemptId
    }

    private func moveToNextUnsettledItem() {
        guard let index = plan.items.indices.first(where: { !isSettled(plan.items[$0].id) }) else { return }
        currentItemIndex = index
        resetRecorder()
    }

    /* 录音中先正常结束再丢弃，保证状态机离开 recording 后才允许 reset。 */
    private func resetRecorder() {
        player.stop()
        if case .recording = recorder.state {
            recorder.stopRecording()
        }
        recorder.discardRecording()
    }

    private static func errorText(for error: BackendError) -> String {
        switch error {
        case .offline:
            return "当前离线，已保存本机进度，联网后确认"
        case .versionConflict:
            return "进度在其他设备被修改，请刷新"
        case .planConflict:
            return "今天已有计划"
        case .planNotComplete:
            return "还有必做题未完成，完成后才能打卡"
        default:
            return "操作失败，请稍后重试"
        }
    }
}
