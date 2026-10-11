# SwiftUI 原生客户端仓库根引导

模板来源：规划材料 RepositoryGuides/SwiftUI/AGENTS.md 1.0（2026-10-11），已按本仓库 docs 布局重写阅读链接。本仓库负责 Mac 上的 SwiftUI 原生 iPhone/iPad 客户端，不换为跨端 UI。后端固定 Python+FastAPI+LangGraph，跨端另仓库为 uni-app x；本仓库不改其实现，不改 MeteorVoice。

## 阅读顺序与权威

1. [项目事实](docs/planning/ProjectFacts.md)：确认已决与未验证范围。
2. [项目工程规范](docs/standards/ProjectEngineeringStandard.md)。
3. [通用工程规范](docs/standards/GeneralEngineeringStandard.md)。
4. [产品需求](docs/planning/ProductRequirements.md)。
5. [技术设计与 EC-API-0.1](docs/planning/TechnicalDesign.md)。
   配套接口附录：[客户端上下文与追踪](docs/planning/ClientContext.md)，统一网络注入、版本与请求关联；命名以项目规范为准。开发前核对[文档审阅与待冻结项](docs/planning/DocumentationAudit.md)。
6. [SwiftUI 实施细则](docs/planning/SwiftUIImplementation.md)。
7. [仓库 README 与快照哈希](README.md)。

项目规范覆盖旧架构/主题冲突，技术设计第 5 节是当前接口唯一来源，事实文件区分用户决定/官方资料/工具输出。不要在此复制规范正文或制造另一契约。

## 执行边界

页面只组合业务与组件；录音/播放/文件/权限/login/theme storage 封装 adapter。SwiftUI 与 uvue 不共享源码，共享语义 token/素材/行为/API；五组十主题按设备保存，不新增主题 server API。
接口由技术设计唯一规定，后端 canonical schema 下发同版本/哈希；内部任务新状态须映射旧 API，不能客户端擅改。代码/注释/空行/计数/主题完整规则引用两份规范，不在此复制值表。
命名：Swift 普通成员/常量 lowerCamelCase，类型/组件/文件基名 UpperCamelCase，枚举 case lowerCamelCase；主题属性 textPrimary/iconPrimary；HTTP header 保留协议写法。
Swift 4 空格缩进、UTF-8 无 BOM/LF/末尾单换行/无 tab/无行尾空格；每手写文件多行职责头（/// 或 /* */），公共 API 多行 ///；MARK/directive 单行例外。
有效行门禁（提醒/硬限）：页面 200/300、shared UI 150/200、state/service 200/300、model 150/250、state-machine 120/200、utils/tokens 120/200、tests 250/350；函数 30/50、类型 150/200（跨 extension 合计）、SwiftUI body 60；注释不计、普通空行计。无 force unwrap、不用 try? 吞错误。

## 当前阶段与证据

阶段 0/1：界面、录音、播放、本地存储、离线流程 + 显式 Debug 模拟服务；不自称云端评测通过。实施进度、验证证据、未完成项与断点续跑分别见 docs/progress/ 下 ImplementationProgress.md、VerificationEvidence.md、OpenItems.md、ResumeNotes.md，随每次提交同步更新。
契约未冻结缺口（技术设计 5.6）不自行补字段；重录最终选择仅实现提交前本地选择。模拟服务覆盖成功/部分失败/无置信度/超时/权限失效/版本冲突/重复日期/离线，界面与报告标"模拟服务"。

## 禁止事项

不创建 GitHub 远程仓库、不部署、不购买服务/充值、不提交密钥与儿童真实录音、不擅自发布 TestFlight/App Store、不自动向其他聊天发消息。密钥/儿童音频不进 Git；日志/截图等敏感证据留本机任务目录。
必须 Mac 实际 Xcode 编译及真机记录；mock 和数学配色不等于通过。未完成的环境/设备/供应商验证如实列入 OpenItems.md。
