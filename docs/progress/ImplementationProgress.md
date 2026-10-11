# 实施进度

记录口径：每条标注【模拟服务】【真实后端】【真实供应商】【设备真实】之一；不以 mock 冒充真实链路。

## 环境核对（阶段 0）

| 项 | 实测结果 | 日期 |
| --- | --- | --- |
| Mac | MacBookPro16,2（2020 Intel 13 英寸四雷雳，对应 A2251 描述）、16GB | 2026-10-11 |
| macOS | 26.7.1 (25G241) | 2026-10-11 |
| Xcode | 26.3 (17C529)，Swift 6.2.4 | 2026-10-11 |
| 已配对真机 | iPhone 15 Pro（iPhone16,1）available/paired | 2026-10-11 |
| 模拟器 | iPhone 16 系列、iPad Pro/Air/mini（iOS 26 运行时） | 2026-10-11 |
| 最低系统 | 暂定 iOS 17.0（@Observable/SwiftData 可用性）；待用户确认 | 2026-10-11 |
| 签名团队 | 待核对（见 OpenItems） | 2026-10-11 |
| iPhone 14 / iPad A1876 | 当前未接入，未验证 | 2026-10-11 |

## 阶段进度

| 阶段 | 内容 | 状态 |
| --- | --- | --- |
| 0 | 仓库创建、文档分发、环境核对、实现设计 | 完成（签名账户未登录如实记录，最低系统 iOS 17.0 暂定待确认） |
| 1 | 界面/录音/回放/重录/反馈状态/日历/收藏/家长页/持久化队列 + 显式模拟服务 | 完成（客户端范围内；71 项测试全绿，iPhone/iPad 模拟器运行验证；真机录音待签名解锁） |
| 2 | 本地真实后端联调 | 未开始（后端仓库未创建） |
| 3 | 真实供应商小批真机试用 | 未开始（需授权与凭据） |
| 4 | 月报 PDF/素材/发布准备 | 未开始 |

## 完成清单（随提交更新）

- 2026-10-11：仓库骨架、8 份权威文档同版快照分发与链接重写、根 README/AGENTS、git 初始化。【工程】
- 2026-10-11：仓库按用户决定更名 SproutIOS（App 名 Sprout，中性命名不含坦克/打卡含义）；xcodegen 2.46.0 生成 Xcode 工程，Xcode 26.3 + iOS 18.5 模拟器构建通过；签名身份 Apple Development: Pengyu Qi（TeamID 9D73T83C47）已在钥匙串，真机签名待实际构建验证。【工程/设备真实】
- 2026-10-11：设计系统完成——十主题完整语义 tokens（ThemeTokens/ThemeCatalog/ThemeFactory，色值忠实映射规范第 6 节）、ThemeStore（本设备 UserDefaults 持久化 group/mode、system 跟随外观）、排版/间距/圆角 token；主题测试 11 项全部通过（iPhone 16 模拟器，iOS 18.5）。【工程】
- 2026-10-11：全量模块集成编译通过——EC-API-0.1 契约模型（未知枚举安全降级）、APIClient/ClientContextProvider（统一 headers、幂等键沿用、错误映射）、MockBackendService 8 场景、录音状态机 + AVFoundation 录音/播放 adapter（中断/权限/磁盘/立即转存）、LocalStore/RecordingFileStore/OfflineQueue/Keychain、10 类共用组件、全部页面（家长设置/今日/练习/完成/日历/收藏/家长/主题设置）。【工程】
- 2026-10-11：62 项单元测试全绿（fixture 语义断言、状态机转移表、离线队列幂等/隔离、持久化往返）；修复 OfflineQueue ISO-8601 亚秒精度丢失。【工程】
- 2026-10-11：SyncCoordinator 离线联网恢复编排（按序重放、沿用幂等键、可重试停止本轮、不可重试列人工处理）+ 6 项测试。【工程】
- 2026-10-11：UI 冒烟测试 3/3 通过（家长设置→今日→复习计划→练习页；tab 切换）；UI 测试暴露并修复两个真实缺陷：LocalStore 缺 @Observable 导致 onboarding 后不刷新、今日 tab 缺 NavigationStack 导致无法导航。总计 71 项测试全绿。【设备真实-模拟器】【模拟服务】
