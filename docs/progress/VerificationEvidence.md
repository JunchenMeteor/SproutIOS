# 验证证据

每条记录：日期、命令、环境、结果、证据位置。模拟/真实严格分级标注。敏感截图与日志留本机任务目录，不进 Git。

## 构建

| 日期 | 命令 | 目标 | 结果 | 备注 |
| --- | --- | --- | --- | --- |
| 2026-10-11 | `xcodebuild -project Sprout.xcodeproj -scheme Sprout -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' build` | iPhone 16 模拟器（iOS 18.5, x86_64） | BUILD SUCCEEDED | 骨架+设计系统阶段 |

## 测试

| 日期 | 命令 | 结果 | 覆盖 |
| --- | --- | --- | --- |
| 2026-10-11 | `xcodebuild test ... name=iPhone 16,OS=18.5` | TEST SUCCEEDED，11/11 通过 | ThemeCatalogTests 7 项（十主题 ID/基础色/主按钮规则/领域组合/状态色/scrim）、ThemeStoreTests 4 项（默认值/持久化/system 跟随/脏数据回退） |

## 真机 / 模拟器

- 模拟器：iPhone 16（iOS 18.5）构建与测试通过（见上）。iPad 模拟器待验证。
- 真机：iPhone 15 Pro 已配对（devicectl 可见），构建/安装待执行；iPhone 14 与 iPad A1876 未接入。
