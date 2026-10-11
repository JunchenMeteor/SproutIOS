# 断点续跑记录

用途：任何会话中断后，从本文件恢复上下文继续工作。

## 当前状态（2026-10-11，阶段 0/1 完成）

- 仓库：`/Users/meteoroid/Projects/SproutIOS`，本地 Git（无远端），main 分支。
- 已完成：docs 快照分发与链接重写；根 README/AGENTS；Xcode 工程（xcodegen，project.yml 为源）；设计系统十主题；契约模型 + APIClient + MockBackendService（8 场景）+ fixtures；录音/播放 adapter + 状态机；LocalStore/RecordingFileStore/OfflineQueue/Keychain；SyncCoordinator 离线恢复编排；10 类共用组件；全部页面；71 项测试全绿（68 单元 + 3 UI 冒烟）。
- 构建：`xcodegen generate && xcodebuild -project Sprout.xcodeproj -scheme Sprout -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' build`；测试同命令换 `test`。
- 验证：iPhone 16 / iPad Pro 13-inch (M4) 模拟器（iOS 18.5）构建、安装、启动、UI 流程通过；截图证据在本机 /tmp/sprout-iphone.png、/tmp/sprout-ipad.png（不进 Git）。
- 真机：iPhone 15 Pro（iOS 27.0.1，UDID 00008130-001E50C80AC0001C）已配对；**签名阻塞**：Xcode 无 Apple 账户会话（Team 9D73T83C47 / G487E5BD5B 均 "No Account for Team"），需用户在 Xcode → Settings → Accounts 登录后重试真机构建。

## 下一步候选（按优先级）

1. 用户登录 Xcode 账户后：真机构建/安装/录音/中断/离线走查（命令见 VerificationEvidence.md 失败行，换 -allowProvisioningUpdates 重试）。
2. iPhone 14 / iPad A1876 接入后逐台验证。
3. 后端仓库创建后进入阶段 2 联调（multipart 上传、canonical schema 哈希核对）。
4. 契约 5.6 冻结后补齐重录选择/sync/导出/删除接口消费。
5. 离线编排补齐：uploadAudio/createAttempt 入队与重放；账号口径对齐（"local-dev-account" vs childId）；接 Network 框架触发 drain。
6. 行数/空行 custom checker（tokenizer/AST 口径）实现后接入流水线。

## 续跑检查单

1. `git log --oneline -8` 与 `git status` 确认最后完成点。
2. 对照 ImplementationProgress.md 完成清单；未完成项见 OpenItems.md。
3. 不要重复已完成工作；验证结果回填 VerificationEvidence.md。
