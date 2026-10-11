/// 离线待同步操作的稳定持久化队列。
/// 职责：以 JSON 文件保存 PendingOperation 列表，每次变更立即原子落盘，
/// 支持按账号隔离查询、失败计数与完成移除。
/// 边界：只保证稳定持久化与状态记录；同一条目内部的执行顺序约束
/// （uploadAudio → createAttempt → checkIn）由调用方按 PendingOperation.Kind.sortRank
/// 排序后依序 drain；重试必须沿用同一 id 作为 Idempotency-Key，不生成新业务完成 ID；
/// 登录失效时保留队列不清空；切账号后只 drain 本账号条目，
/// 未经确认不上传旧账号的儿童音频。
/// 副作用：在 Application Support/OfflineQueue（或注入目录）读写 queue.json。
/// 约束：非线程安全，调用方须在主线程或同一串行上下文使用。
import Foundation

/// 一条待同步操作；id 为稳定幂等键，重试沿用不更换。
struct PendingOperation: Codable, Identifiable, Equatable {
    /// 操作种类。
    enum Kind: String, Codable {
        /// 上传录音文件；payloadJSON 内携带关联的 recordingID。
        case uploadAudio
        /// 创建 attempt。
        case createAttempt
        /// 打卡。
        case checkIn

        /// drain 顺序权重：录音先于 attempt，attempt 先于打卡。
        var sortRank: Int {
            switch self {
            case .uploadAudio: return 0
            case .createAttempt: return 1
            case .checkIn: return 2
            }
        }
    }

    /// 稳定 UUID 幂等键；服务端 Idempotency-Key 直接使用它，重试不更换。
    let id: UUID
    /// 操作种类。
    var kind: Kind
    /// 契约未冻结期间的原始 JSON 载荷。
    var payloadJSON: Data
    /// 首次入队时间（客户端声明时间）。
    var createdAt: Date
    /// 已失败次数，供有界重试判断。
    var retryCount: Int
    /// 最近一次失败原因。
    var lastError: String?
    /// 所属账号标识，切账号隔离据此过滤。
    var accountID: String

    init(
        id: UUID = UUID(),
        kind: Kind,
        payloadJSON: Data,
        createdAt: Date = Date(),
        retryCount: Int = 0,
        lastError: String? = nil,
        accountID: String
    ) {
        self.id = id
        self.kind = kind
        self.payloadJSON = payloadJSON
        self.createdAt = createdAt
        self.retryCount = retryCount
        self.lastError = lastError
        self.accountID = accountID
    }
}


/// 队列操作失败。
enum OfflineQueueError: Error {
    /// 指定 id 的操作不存在。
    case operationNotFound(UUID)
    /// 队列文件无法解码；调用方决定备份重建或上报，本层不静默清空。
    case corruptedState(underlying: Error)
}


final class OfflineQueue {
    private static let fileName = "queue.json"

    private let fileURL: URL
    private var operations: [PendingOperation]

    /// 注入目录便于测试；默认 Application Support/OfflineQueue。队列文件损坏时抛错，不吞错。
    init(directory: URL? = nil, fileManager: FileManager = .default) throws {
        let root: URL
        if let directory {
            root = directory
        } else {
            root = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            ).appendingPathComponent("OfflineQueue", isDirectory: true)
        }
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        fileURL = root.appendingPathComponent(Self.fileName)
        operations = try Self.load(from: fileURL)
    }

    /// 入队并立即原子落盘；同 id 已存在时忽略（幂等，重复入队不产生第二条）。
    func enqueue(_ operation: PendingOperation) throws {
        guard !operations.contains(where: { $0.id == operation.id }) else { return }
        operations.append(operation)
        try persistNow()
    }

    /// 按账号过滤的待执行列表，按 createdAt 升序；
    /// 跨 kind 的执行顺序由调用方按 sortRank 再排。
    func pending(forAccount accountID: String) -> [PendingOperation] {
        operations
            .filter { $0.accountID == accountID }
            .sorted { $0.createdAt < $1.createdAt }
    }

    /// 记录一次失败：retryCount 加一、记下原因并落盘；id 沿用不变。
    func markFailed(_ id: UUID, error: String) throws {
        guard let index = operations.firstIndex(where: { $0.id == id }) else {
            throw OfflineQueueError.operationNotFound(id)
        }
        operations[index].retryCount += 1
        operations[index].lastError = error
        try persistNow()
    }

    /// 服务端确认后移除条目并立即落盘。
    func markCompleted(_ id: UUID) throws {
        guard let index = operations.firstIndex(where: { $0.id == id }) else {
            throw OfflineQueueError.operationNotFound(id)
        }
        operations.remove(at: index)
        try persistNow()
    }

    /* ISO-8601 带小数秒，避免 createdAt 持久化往返丢亚秒精度；
       解码兼容早期无小数秒格式。 */
    private static let iso8601Fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private func persistNow() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(Self.iso8601Fractional.string(from: date))
        }
        let data = try encoder.encode(operations)
        try data.write(to: fileURL, options: .atomic)
    }

    private static func load(from fileURL: URL) throws -> [PendingOperation] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom { container in
                let text = try container.singleValueContainer().decode(String.self)
                if let date = iso8601Fractional.date(from: text) {
                    return date
                }
                let plain = ISO8601DateFormatter()
                plain.formatOptions = [.withInternetDateTime]
                if let date = plain.date(from: text) {
                    return date
                }
                throw DecodingError.dataCorruptedError(
                    in: try container.singleValueContainer(),
                    debugDescription: "非法 ISO-8601 时间: \(text)")
            }
            return try decoder.decode([PendingOperation].self, from: Data(contentsOf: fileURL))
        } catch {
            throw OfflineQueueError.corruptedState(underlying: error)
        }
    }
}
