# SproutIOS

英语练习打卡 App 的 SwiftUI 原生客户端仓库（iPhone / iPad），三仓库之一。另两仓库为 Python + FastAPI + LangGraph 后端与 uni-app x 跨端客户端，均不在本仓库内，本仓库不修改 MeteorVoice。

- 创建日期：2026-10-11；接口契约：EC-API-0.1（设计初稿，未冻结，见技术设计第 5.6 节）
- 权威依据：随库分发的同版文档快照（见下表），接口唯一来源为技术设计第 5 节
- 当前阶段：阶段 0/1——界面、录音、播放、本地存储、离线流程 + 显式标记的模拟服务（Debug）；无真实后端、无真实供应商

## 阅读顺序

1. [项目事实](docs/planning/ProjectFacts.md)：已决 / 建议 / 未决与验证边界
2. [项目工程规范](docs/standards/ProjectEngineeringStandard.md)：架构、编码、十套主题 tokens
3. [通用工程规范](docs/standards/GeneralEngineeringStandard.md)：模块、组件、计数门禁基线
4. [产品需求](docs/planning/ProductRequirements.md)
5. [技术设计与 EC-API-0.1](docs/planning/TechnicalDesign.md) + [客户端上下文与追踪](docs/planning/ClientContext.md)
6. [文档审阅与待冻结项](docs/planning/DocumentationAudit.md)
7. [SwiftUI 实施细则](docs/planning/SwiftUIImplementation.md)：本仓库的执行范围与阶段验收

## 随库文档快照（版本 / SHA-256）

| 文件 | 版本 | SHA-256（前 16 位） |
| --- | --- | --- |
| docs/planning/ProductRequirements.md | v0.4 / 2026-10-11 | 41762ab9045870b3 |
| docs/planning/TechnicalDesign.md | 设计 v0.4 / EC-API-0.1 | ce0dfd31a587be20 |
| docs/planning/ClientContext.md | 1.1 / 2026-10-11 | 621539b89fc47aa0 |
| docs/planning/ProjectFacts.md | 1.3 / 2026-10-11 | 4b390a060e9f93de |
| docs/planning/DocumentationAudit.md | 1.0 / 2026-10-11 | 6e1fd3b84b8cb07f |
| docs/planning/SwiftUIImplementation.md | v0.4 / 2026-10-11 | 419914352ac02cf349 |
| docs/standards/ProjectEngineeringStandard.md | 1.1 / 2026-10-11 | 3bcda697bd527917 |
| docs/standards/GeneralEngineeringStandard.md | 1.1 / 2026-10-11 | 54f45d3db06a04fb |

快照从规划材料目录同版复制，相对链接已按本仓库 docs 布局重写；源材料统一更新后再分发，不在本仓库单独演变正文。完整哈希可用 `shasum -a 256 docs/planning/*.md docs/standards/*.md` 复算。

## 目录

```text
AGENTS.md                  # 仓库根引导（≤200 行）
docs/planning/             # 产品、技术、事实、审阅、SwiftUI 实施同版快照
docs/standards/            # 项目与通用两规范同版快照
docs/progress/             # 实施进度、验证证据、未完成项、断点续跑记录
contracts/                 # EC-API-0.1 派生 fixture；canonical schema 待后端仓库发布
Sprout/                    # App target 源码
  App/                     # 组合根、生命周期
  Design/                  # 语义 tokens、十主题映射
  UI/Components/           # 共用 UI 组件（button/dialog/toast/form/list/card/recorder/feedback/calendar/reward）
  Features/                # 家长设置、今日、练习、完成、日历、收藏、家长页
  Services/                # APIClient、ClientContext、录音/播放平台 adapter、模拟服务
  Storage/                 # 计划快照、草稿、录音引用、幂等键、离线队列
Tests/                     # 单元测试（契约 fixture 断言、状态机、持久化恢复）
```

## 构建与验证

- 工具链：Xcode 26.3（Swift 6.2.4），macOS 26.7.1，MacBookPro16,2（Intel）
- 最低系统：iOS 17.0（待用户确认；依据：@Observable / SwiftData 可用性与在保设备核对，见 docs/progress/）
- 模拟器构建：`xcodebuild -project Sprout.xcodeproj -scheme Sprout -destination 'platform=iOS Simulator,name=iPhone 16' build`
- 测试：`xcodebuild test -project Sprout.xcodeproj -scheme Sprout -destination 'platform=iOS Simulator,name=iPhone 16'`
- 每次验证的实际命令、结果与证据见 [docs/progress/VerificationEvidence.md](docs/progress/VerificationEvidence.md)

## 边界（不做什么）

契约 EC-API-0.1 未冻结前不自行定义远端接口；模拟服务在界面与报告中显著标注"模拟服务"。不创建 GitHub 远程仓库、不部署、不购买/充值任何服务、不提交密钥与儿童真实录音、不擅自提交 TestFlight/App Store。真机/供应商/教材许可等待确认项见 [docs/progress/OpenItems.md](docs/progress/OpenItems.md)。
