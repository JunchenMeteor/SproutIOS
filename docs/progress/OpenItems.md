# 未完成项与待确认

来源：规划 README 集中待确认列表与技术设计 5.6，本仓库只列客户端相关项。

## 阻塞客户端验收的待确认（需用户决定）

| 项 | 影响 | 当前处理 |
| --- | --- | --- |
| 最低 iOS/iPadOS 版本确认 | deployment target | 暂定 iOS 17.0，可构建验证，待确认 |
| **Xcode 无 Apple 账户会话（真机签名阻塞）** | 真机构建/安装 | 2026-10-11 实测：钥匙串有两个 Apple Development 证书（9D73T83C47 / G487E5BD5B），但两个 Team 均无 Xcode 账户登录会话，-allowProvisioningUpdates 报 "No Account for Team"；本机 4 个 mobileprovision 全部 2022 年过期且属其他 Team/应用。**需要用户在 Xcode → Settings → Accounts 登录 Apple ID 后告知，即可继续真机验证** |
| 清华版教材准确版本/ISBN/课次/素材许可 | 真实课程内容 | 仅用原创演示 fixture，明确标注 |
| 家长登录/账号恢复方式 | 真实联调 | 仅本机开发身份（Debug 模拟），不上线 |
| 云端 STT/专业评测/TTS 供应商与凭据 | 阶段 3 | 不接，模拟服务标注 |
| 契约 5.6 冻结缺口（重录选择/课程读取/同步快照/通用 schema/登录附录） | 远端接口 | 不自行定义；仅提交前本地重录选择 |

## 客户端范围内未完成

- iPhone 14、iPad A1876 真机未接入：录音/中断/离线/布局未在这两台验证。
- 行数/空行 custom checker 未实现（规范要求 tokenizer/AST 口径）：当前人工遵守 + 子任务脚本自检，未自动门禁。
- 十主题×主要组件状态的 UI 逐项验收未做（数学配色不代替 UI）。
- 离线编排缺口：uploadAudio/createAttempt 的 PendingOperation 载荷未入队、重放编排未建（SyncCoordinator 只对 checkIn 重放；multipart 上传待真实后端联调）。
- 账号口径缺口：SyncCoordinator drain 用常量 "local-dev-account"，练习页入队用 plan.childId，登录体系落地后必须对齐，否则离线条目不会被正确 drain。
- 无网络监听：联网恢复触发靠 RootTabView 启动时一次 drain + 占位注释，待接 Network 框架。

## 明确不做

不建远端仓库、不部署、不充值、不内置未许可教材、不把模拟服务结果称为云端评测通过。
