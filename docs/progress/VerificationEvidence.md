# 验证证据

每条记录：日期、命令、环境、结果、证据位置。模拟/真实严格分级标注。敏感截图与日志留本机任务目录，不进 Git。

## 构建

| 日期 | 命令 | 目标 | 结果 | 备注 |
| --- | --- | --- | --- | --- |
| 2026-10-11 | `xcodebuild -project Sprout.xcodeproj -scheme Sprout -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' build` | iPhone 16 模拟器（iOS 18.5, x86_64） | BUILD SUCCEEDED | 骨架+设计系统阶段 |
| 2026-10-11 | 同上（全量集成后） | iPhone 16 模拟器 | BUILD SUCCEEDED | 全模块（模型/服务/录音/存储/组件/页面）集成编译通过；修复：Configuration 类型与 ButtonStyle.Configuration 冲突改名 ContractConfiguration、iOS 26 SDK URLError.Code.notConnectedToInternet 改名适配、@MainActor 组合根、元组标签 |
| 2026-10-11 | `xcodebuild ... -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4),OS=18.5' build` | iPad 模拟器 | BUILD SUCCEEDED | TARGETED_DEVICE_FAMILY=1,2 |
| 2026-10-11 | `xcodebuild ... -destination 'platform=iOS,id=00008130-001E50C80AC0001C' -allowProvisioningUpdates build` | iPhone 15 Pro 真机（iOS 27.0.1） | **BUILD FAILED（签名）** | "No Account for Team 9D73T83C47/G487E5BD5B"：钥匙串有证书但 Xcode 无对应账户会话；本机 4 个描述文件全部 2022 过期且属 V64TJ75HYC 其他应用。需用户登录 Xcode 账户 |

## 测试

| 日期 | 命令 | 结果 | 覆盖 |
| --- | --- | --- | --- |
| 2026-10-11 | `xcodebuild test ... name=iPhone 16,OS=18.5` | TEST SUCCEEDED，11/11 通过 | ThemeCatalogTests 7 项（十主题 ID/基础色/主按钮规则/领域组合/状态色/scrim）、ThemeStoreTests 4 项（默认值/持久化/system 跟随/脏数据回退） |
| 2026-10-11 | 同上（全量） | TEST SUCCEEDED，62/62 通过 | 新增 51 项：BusinessDate 10、契约枚举 unknown 降级 9、fixture 解码语义 9、录音状态机 10、离线队列 8、LocalStore 5。修复 OfflineQueue ISO-8601 亚秒精度往返丢失（测试暴露的真实 bug） |

## 真机 / 模拟器

- 模拟器：iPhone 16（iOS 18.5）构建与测试通过（见上）；iPhone 16 模拟器安装并启动成功，家长设置首屏渲染正确（主题 SkyLight、模拟服务横幅显示）【设备真实-模拟器】。
- iPad Pro 13-inch (M4)（iOS 18.5）：构建通过、安装启动成功、首屏渲染正确【设备真实-模拟器】。
- 真机：iPhone 15 Pro（iOS 27.0.1）已配对；构建因 Xcode 无 Apple 账户会话被签名阻塞（见上表），待用户登录 Xcode → Settings → Accounts 后继续。iPhone 14 与 iPad A1876 未接入。
