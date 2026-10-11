/// 客户端上下文与诊断 headers 组装（实现 docs/planning/ClientContext.md）。
/// 职责：集中生成 X-Client-*、X-Contract-Version 等诊断 headers，页面不得逐接口拼装。
/// 边界：全部是客户端声明，可伪造，不能当认证或儿童身份；
///       不读取 IMEI/MAC/IDFA 等硬件/广告标识。
/// 副作用：首次构建向 UserDefaults 持久化 installationId；读取 Bundle/ProcessInfo/UIDevice。
/// 约束：仅由统一网络模块向 App API 域名注入；预签名第三方下载 URL 不附带这些 headers。
import UIKit


/// 一次启动内的客户端上下文快照。
/// clientSessionId 每次启动重新生成；installationId 持久化但存储重置后可能变化。
struct ClientContext: Sendable {
    /// 客户端实现系列，固定 "swiftui"。
    let clientType: String
    /// 运行平台：iPhone 为 "ios"，iPad 为 "ipados"（按 userInterfaceIdiom 判定）。
    let clientPlatform: String
    /// 可发布应用版本（CFBundleShortVersionString）。
    let appVersion: String
    /// 发布构建编号（CFBundleVersion），不含秘密。
    let appBuild: String
    /// 低精度系统版本（主版本.次版本）。
    let osVersion: String
    /// 随机安装实例标识（UserDefaults 持久化）。
    let installationId: String
    /// 本次使用会话随机标识（每次启动新 UUID）。
    let clientSessionId: String
    /// 契约版本，固定 "EC-API-0.1"。
    let contractVersion: String

    /// 产出全部诊断 headers：X-Client-Type/X-Client-Platform/X-App-Version/X-App-Build/
    /// X-OS-Version/X-Installation-Id/X-Client-Session-Id/X-Contract-Version。
    /// 仅向 App API 域名注入；诊断 ID 是声明不是认证令牌，不能用于授权判断。
    func makeHeaders() -> [String: String] {
        [
            "X-Client-Type": clientType,
            "X-Client-Platform": clientPlatform,
            "X-App-Version": appVersion,
            "X-App-Build": appBuild,
            "X-OS-Version": osVersion,
            "X-Installation-Id": installationId,
            "X-Client-Session-Id": clientSessionId,
            "X-Contract-Version": contractVersion
        ]
    }
}


/// ClientContext 构建器。
/// 集中读取 Bundle/UserDefaults/UIDevice/ProcessInfo，便于测试注入替身。
enum ClientContextProvider {
    /// installationId 的 UserDefaults 键。
    static let installationIdKey = "sprout.client.installationId"

    /// 构建当前启动的 ClientContext。
    /// installationId 缺省时生成随机 UUID 并持久化（默认启用，可缺省）；
    /// clientSessionId 每次调用生成新值。
    static func makeContext(
        bundle: Bundle = .main,
        defaults: UserDefaults = .standard,
        device: UIDevice = .current,
        processInfo: ProcessInfo = .processInfo
    ) -> ClientContext {
        let info = bundle.infoDictionary ?? [:]
        let osVersion = processInfo.operatingSystemVersion
        return ClientContext(
            clientType: "swiftui",
            clientPlatform: device.userInterfaceIdiom == .pad ? "ipados" : "ios",
            appVersion: info["CFBundleShortVersionString"] as? String ?? "0.0.0",
            appBuild: info["CFBundleVersion"] as? String ?? "0",
            osVersion: "\(osVersion.majorVersion).\(osVersion.minorVersion)",
            installationId: loadOrCreateInstallationId(defaults: defaults),
            clientSessionId: UUID().uuidString,
            contractVersion: "EC-API-0.1"
        )
    }

    /// 读取或创建持久化 installationId。
    /// 存储重置后重新生成是预期行为，不代表新设备或新用户。
    private static func loadOrCreateInstallationId(defaults: UserDefaults) -> String {
        if let existing = defaults.string(forKey: installationIdKey) {
            return existing
        }
        let created = UUID().uuidString
        defaults.set(created, forKey: installationIdKey)
        return created
    }
}
