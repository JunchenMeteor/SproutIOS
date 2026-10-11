/// 应用会话令牌的 Keychain 存取。
/// 职责：以 kSecClassGenericPassword 保存、读取、删除指定账号的会话令牌，
/// 访问级别固定为 kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly（不随备份迁移到新设备）。
/// 边界：只放 App 会话令牌；厂商长效密钥（STT/评测/TTS 供应商密钥）永远不进 App，
/// 自然也不进本存储；不承载其他业务数据。
/// 副作用：读写系统 Keychain。
/// 约束：写与删显式 throws；读按任务书签名为非 throws，异常与不存在都返回 nil，
/// 调用方按“需要重新登录”处理，不因读取故障崩溃。
import Foundation
import Security

/// Keychain 操作失败。
enum KeychainError: Error {
    /// SecItem* 返回了未单独归类的 OSStatus。
    case unhandledStatus(OSStatus)
}


enum KeychainHelper {
    private static let service = "com.meteoroid.Sprout.session"

    /// 保存（或覆盖）指定账号的会话令牌。
    static func saveToken(_ token: String, account: String) throws {
        let attributes: [String: Any] = [
            kSecValueData as String: Data(token.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let query = baseQuery(account: account)
        let lookupStatus = SecItemCopyMatching(query as CFDictionary, nil)
        if lookupStatus == errSecItemNotFound {
            var addQuery = query
            addQuery.merge(attributes) { _, new in new }
            try check(SecItemAdd(addQuery as CFDictionary, nil))
        } else {
            try check(lookupStatus)
            try check(SecItemUpdate(query as CFDictionary, attributes as CFDictionary))
        }
    }

    /// 读取指定账号的会话令牌；不存在或读取异常返回 nil（见文件头约束）。
    static func readToken(account: String) -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }
        return token
    }

    /// 删除指定账号的会话令牌；不存在视为成功（幂等，登出/切账号可重复调用）。
    static func deleteToken(account: String) throws {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        guard status != errSecItemNotFound else { return }
        try check(status)
    }

    private static func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    private static func check(_ status: OSStatus) throws {
        guard status == errSecSuccess else {
            throw KeychainError.unhandledStatus(status)
        }
    }
}
