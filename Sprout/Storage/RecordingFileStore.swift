/// 录音文件的持久目录管理。
/// 职责：把录制完成的临时文件立即 move 进持久目录（文件名 <uuid>.m4a）、
/// 按 id 解析 URL 与文件大小、删除指定文件、按引用集合清理孤儿片段。
/// 边界：不维护引用计数本身，哪些 id 仍被草稿/attempt 引用由调用方以 Set 传入；
/// 不校验音频内容完整性（损坏片段不自动提交由录音与上传层负责）。
/// 副作用：在 Application Support/Recordings（或注入目录）创建、移动、删除文件。
/// 约束：同卷 move 为原子 rename，临时目录与 Application Support 同卷，无半文件可见；
/// 录制侧必须先完全关闭文件再调用 persistTemporaryRecording。
import Foundation

struct RecordingFileStore {
    /// 录音文件统一扩展名。
    static let fileExtension = "m4a"

    private let rootDirectory: URL
    private let fileManager: FileManager

    /// 注入根目录便于测试；默认 Application Support/Recordings，目录不存在自动创建。
    init(rootDirectory: URL? = nil, fileManager: FileManager = .default) throws {
        self.fileManager = fileManager
        if let rootDirectory {
            self.rootDirectory = rootDirectory
        } else {
            let support = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            self.rootDirectory = support.appendingPathComponent("Recordings", isDirectory: true)
        }
        try fileManager.createDirectory(at: self.rootDirectory, withIntermediateDirectories: true)
    }

    /// 把录制完成的临时文件立即移动到持久目录并返回持久 URL；
    /// 同 id 已存在时先删除旧文件再覆盖。
    func persistTemporaryRecording(from tempURL: URL, id: UUID) throws -> URL {
        let destination = fileURL(for: id)
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.moveItem(at: tempURL, to: destination)
        return destination
    }

    /// 返回 id 对应的持久文件 URL；文件不存在返回 nil。
    func url(for id: UUID) -> URL? {
        let url = fileURL(for: id)
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }

    /// 删除 id 对应的文件；不存在视为成功（幂等，重试安全）。
    func delete(id: UUID) throws {
        let url = fileURL(for: id)
        guard fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.removeItem(at: url)
    }

    /// 清理未被任何草稿/attempt 引用的废弃片段；
    /// 文件名不是合法 UUID 的条目保守跳过不删。
    func discardOrphans(keeping referencedIds: Set<UUID>) throws {
        let names = try fileManager.contentsOfDirectory(atPath: rootDirectory.path)
        for name in names {
            guard let id = UUID(uuidString: (name as NSString).deletingPathExtension),
                  !referencedIds.contains(id) else {
                continue
            }
            try fileManager.removeItem(at: rootDirectory.appendingPathComponent(name))
        }
    }

    /// 文件字节数；文件不存在或属性读取失败返回 nil（调用方按不可用处理）。
    func fileSize(id: UUID) -> Int64? {
        do {
            let attributes = try fileManager.attributesOfItem(atPath: fileURL(for: id).path)
            return (attributes[.size] as? NSNumber)?.int64Value
        } catch {
            return nil
        }
    }

    private func fileURL(for id: UUID) -> URL {
        rootDirectory
            .appendingPathComponent(id.uuidString)
            .appendingPathExtension(Self.fileExtension)
    }
}
