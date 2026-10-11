/// 离线队列的联网恢复编排层。
/// 职责：应用启动或网络恢复后，按 PendingOperation.Kind.sortRank 约束
/// （uploadAudio → createAttempt → checkIn）逐条重放本账号的待同步操作；
/// 成功即移除，可重试失败保留待下轮，不可重试失败记入摘要待人工处理。
/// 边界：首版只实际重放 checkIn；uploadAudio/createAttempt 载荷目前未入队，
///       若队列中出现则跳过并在摘要注明「等待上传编排层」，不伪造 multipart 编排。
///       重复日期由服务端幂等去重（重复提交返回已有记录且不再发奖），本层不重复发奖。
/// 副作用：调用后端写接口；经 OfflineQueue 落盘状态变更。
/// 约束：@MainActor 串行；isDraining 期间重入直接返回；重试沿用 PendingOperation.id
///       作为 Idempotency-Key，不生成新业务 ID；Task 取消时停止本轮。
import Foundation


/// 重放单条操作的处置结果。
private enum ReplayOutcome {
    /// 服务端已确认，条目移除。
    case completed
    /// 可重试失败，停止本轮，其余留待下轮。
    case retryLater
    /// 不可重试失败，需人工处理。
    case needsManual(String)
}


/// 联网恢复编排器；由 AppEnvironment 装配，界面/日志经 lastDrainSummary 展示本轮结果。
@MainActor
@Observable
final class SyncCoordinator {
    /// 是否正在 drain；期间重入直接返回。
    private(set) var isDraining = false
    /// 最近一轮 drain 的中文摘要（供界面/日志展示）。
    private(set) var lastDrainSummary: String?

    private let queue: OfflineQueue
    private let backend: any BackendService
    /// 本轮队列落盘异常（不吞错，汇总进摘要）。
    private var persistWarnings: [String] = []

    init(queue: OfflineQueue, backend: any BackendService) {
        self.queue = queue
        self.backend = backend
    }

    /// 按 sortRank 顺序重放指定账号的待同步操作；重入与空队列安全。
    /// 只 drain 本账号条目，切账号隔离由 OfflineQueue.pending(forAccount:) 保证。
    func drainPending(forAccount accountID: String) async {
        guard !isDraining else { return }
        isDraining = true
        defer { isDraining = false }
        persistWarnings = []

        let operations = queue.pending(forAccount: accountID)
            .sorted { lhs, rhs in
                if lhs.kind.sortRank != rhs.kind.sortRank {
                    return lhs.kind.sortRank < rhs.kind.sortRank
                }
                return lhs.createdAt < rhs.createdAt
            }
        var completed = 0
        var deferred = 0
        var manual: [String] = []
        var halted = false
        var cancelled = false

        for operation in operations {
            if Task.isCancelled {
                cancelled = true
                break
            }
            guard operation.kind == .checkIn else {
                deferred += 1
                continue
            }
            switch await replayCheckIn(operation) {
            case .completed:
                completed += 1
            case .needsManual(let reason):
                manual.append(reason)
            case .retryLater:
                halted = true
            }
            if halted { break }
        }
        lastDrainSummary = makeSummary(
            total: operations.count, completed: completed, deferred: deferred,
            manual: manual, halted: halted, cancelled: cancelled)
    }

    /// 重放一条 checkIn：幂等键沿用 operation.id（入队时即 clientCompletionId），
    /// 重试沿用同一稳定幂等键，不生成新业务 ID。
    private func replayCheckIn(_ operation: PendingOperation) async -> ReplayOutcome {
        let payload: PendingCheckInPayload
        do {
            payload = try ContractJSON.makeDecoder().decode(
                PendingCheckInPayload.self, from: operation.payloadJSON)
        } catch {
            return fail(operation, reason: "载荷无法解码", retryable: false)
        }
        do {
            // 重复日期由服务端幂等处理（返回已有记录、rewardGrants 为空），成功即移除，不重复发奖。
            _ = try await backend.createCheckIn(
                childId: payload.childId, planId: payload.planId, targetDate: payload.targetDate,
                clientCompletionId: payload.clientCompletionId,
                clientCompletedAt: payload.clientCompletedAt,
                planRevision: payload.planRevision, itemOutcomes: payload.itemOutcomes,
                idempotencyKey: operation.id.uuidString)
            complete(operation)
            return .completed
        } catch let error as BackendError {
            return fail(operation, reason: Self.describe(error), retryable: error.retryable)
        } catch {
            return fail(operation, reason: "未知错误: \(error.localizedDescription)", retryable: false)
        }
    }

    /// 成功移除条目；落盘异常记入本轮警告，不吞错。
    private func complete(_ operation: PendingOperation) {
        do {
            try queue.markCompleted(operation.id)
        } catch {
            persistWarnings.append("移除 \(operation.id.uuidString) 失败: \(error.localizedDescription)")
        }
    }

    /// 记录失败并返回处置结果；落盘异常记入本轮警告。
    private func fail(_ operation: PendingOperation, reason: String, retryable: Bool) -> ReplayOutcome {
        do {
            try queue.markFailed(operation.id, error: reason)
        } catch {
            persistWarnings.append("记录 \(operation.id.uuidString) 失败: \(error.localizedDescription)")
        }
        return retryable ? .retryLater : .needsManual(reason)
    }

    /// 汇总本轮结果的中文摘要。
    private func makeSummary(
        total: Int, completed: Int, deferred: Int,
        manual: [String], halted: Bool, cancelled: Bool
    ) -> String {
        if total == 0 { return "没有待同步的离线操作" }
        var parts = ["本轮离线同步：成功 \(completed) 条"]
        if deferred > 0 { parts.append("\(deferred) 条等待上传编排层") }
        if !manual.isEmpty {
            parts.append("\(manual.count) 条需人工处理（\(manual.joined(separator: "；"))）")
        }
        if halted { parts.append("网络或服务不可用，其余待下轮重试") }
        if cancelled { parts.append("同步已取消") }
        if !persistWarnings.isEmpty { parts.append("队列落盘异常 \(persistWarnings.count) 处") }
        return parts.joined(separator: "；")
    }

    /// 错误的中文简述（面向家长/开发者，不含敏感信息）。
    private static func describe(_ error: BackendError) -> String {
        switch error {
        case .offline: return "网络不可用"
        case .versionConflict: return "进度版本冲突"
        case .planConflict: return "已有当日计划"
        case .planNotComplete: return "计划未完成"
        case .dateNotAllowed: return "日期不允许补卡"
        case .quotaExceeded: return "超出配额"
        case .providerUnavailable: return "服务暂不可用"
        case .providerTimeout: return "服务超时"
        default: return "服务端拒绝"
        }
    }
}
