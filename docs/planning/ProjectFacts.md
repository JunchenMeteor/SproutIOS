# 项目事实与决策记录
版本：1.3；记录日期：2026-10-11；用途：跨窗口交接的事实基线，不能把计划当已完成实现。
这是本次授权新建的独立事实文件。原交付只有 README + 产品/技术/SwiftUI/后端四文，没有已读取的旧独立事实文件；本次没有声称发现或读取过不存在的事实文档。
当前规范：[项目工程规范](../standards/ProjectEngineeringStandard.md)、[通用工程规范](../standards/GeneralEngineeringStandard.md)；业务需求：[ProductRequirements.md](./ProductRequirements.md)；接口唯一来源：[TechnicalDesign.md](./TechnicalDesign.md) 第5节 EC-API-0.1。架构/主题/工程冲突以新规范优先，接口不暗改。

## 1. 来源与可信范围
| 来源类别 | 可支持的事实 | 不可推出的结论 |
| --- | --- | --- |
| 用户决策（本会话与来源聊天交接） | 三仓库、框架、业务范围、十主题、编码规则、文档修改授权 | 仓库/服务已创建，所有技术建议已批准 |
| 官方资料（来源聊天已查，本文保留链接） | 文档所述能力/默认规则、核对入口 | 当前账户权限、真实API可用/准确/廉价、目标端已编译 |
| 本窗口工具输出 | 补丁保存/上下文更新成功；纯JS行数/配色计算；运行时失败 | 独立落盘字节实测、UI/真机/云端质量已通过 |
| 来源聊天独立数学复核报告 | 主聊天报告258项配色核验失败0 | 本窗口再次亲自执行258项，或258个设备/UI测试 |
| 配色概念图/演示/mock | 展示方向、模拟状态与布局 | 精确色值/可访问性/供应商效果/费用验证 |

## 2. 用户已确认的稳定约束
| 项目 | 已确认事实 |
| --- | --- |
| 仓库 | 三个独立仓库：SwiftUI原生iPhone/iPad；Python+FastAPI+LangGraph后端；uni-app x跨端 |
| 开发与部署背景 | Mac开发编译签名SwiftUI；Windows开发后端/跨端；后端未来个人服务器，本次不部署 |
| 跨端目标 | 微信小程序、Web、Android、原生HarmonyOS NEXT；纯鸿蒙不是Android兼容APK |
| 架构排除 | 不换SwiftUI或Python后端，不用Taro/Mastra/TS后端，不用React Native替代；单体可独立worker，不无必要微服务 |
| AI | 全云端由后端调用，无端侧模型，无流式；按键完整录音后上传，无实时字幕/自动判停/抢话 |
| 评价 | 跟读原音+参考句专业发音；自由表达STT原话→文字语法/用词，发音另评；文本模型不能从转写判断发音 |
| 教材与计划 | 家长确认清华版二年级准确教材/已学范围；新课确认才推进，复习/没课/未知不推进；短题至少5分钟目标 |
| 完成与离线 | 基础完成不依赖高分或评价成功；草稿/录音/队列持久化，联网恢复 |
| 日期与奖励 | targetDate与实际确认/client声明时间分开；补卡保留事实；后端权威跨设备/重复去重发奖 |
| 收藏 | 坦克/零件徽章/涂装展台，原始历史型号与来源保留；合法/原创素材，不战斗/抽卡/多币种 |
| 数据 | 报告CSV/PDF不同于可恢复备份/导入；长期录音家长选择，删除/供应商/备份期限须诚实说明 |
| 服务限制 | DeepSeek文字候选，专业评测待实测；豆包首期不接，Kimi订阅不等于API余额；密钥只在后端 |

## 3. 用户已确认的主题与工程规则
默认暖白+浅蓝B、学习页简洁、解锁动画精彩可跳过；五配色组×两明暗，模式system/light/dark，按设备本地保存，不强制跨设备同步，不新增主题server API。
| group存储键 | Light ID / 名称 / accent / page | Dark ID / 名称 / accent / page |
| --- | --- | --- |
| sky（默认） | SkyLight / 晴空蓝 / #87CEFA / #FAF8F3 | SkyDark / 午夜晴空 / #87CEFA / #101827 |
| mist | MistLight / 雾蓝晨光 / #B8D4F0 / #F7F9FC | MistDark / 深海星光 / #8BAAF5 / #111A30 |
| lavender | LavenderLight / 薰衣草 / #C4B5FD / #FAF8FF | LavenderDark / 紫夜银河 / #B9A0FF / #1B162A |
| peach | PeachLight / 蜜桃奶油 / #FDBA9A / #FFF8F2 | PeachDark / 琥珀夜色 / #F2BB67 / #211B16 |
| lemon | LemonLight / 柠檬晴日 / #F4D96B / #FFFCF1 | LemonDark / 石墨冰蓝 / #A7C7E7 / #181C22 |

完整语义token值及组合只以项目规范第6节为权威，以上accent/page摘要不代替背景/文字/图标/按钮/链接/选中焦点/状态/录音进度日历奖励。主题ID UpperCamelCase为具名project profile覆盖；存储group lowerCamelCase，mode固定枚举。
共享的是语义token、许可素材、组件行为/API/规则，不是SwiftUI与uvue源码。页面只组合，共用button/dialog-sheet/toast-banner/form/list-pagination/card-container/recorder/feedback/calendar/reward；平台录音/文件/权限/login/theme storage集中adapter，Web录音独立。
手写代码有有意义的多行职责/公共API/复杂逻辑注释；统计注释不计、普通空白行计、inline代码计1，AST真docstring才排除，prompt/SQL计代码；条件directive计有效代码。声明间“空格”明确为空行：type/class2、function/method1、类型函数边界优先2，无超过2，Python有意偏离PEP8顶层函数2默认。
UTF8无BOM/LF/末尾单换行/无tab尾空格，py/Swift/PS4空格、UTS/uvue等2。文件/函数/类型阈值与复杂度、tokenizer/AST计数、格式化幂等流水线、命名/导入/例外详细规则已写入两份规范；这些是要求，不是已经实现的checker。
LangGraph checkpoint不替代任务调度/业务DB，不保证exactly-once；内部queued/running/retry_wait/succeeded/partial_success/failed/cancelled，租约/revision/有限重试/恢复/取消迟到保护/调用记录。EC-API-0.1仍retry_wait映射queued、partial_success映射partial，原接口字段/枚举保持，不暗改客户端契约。

## 4. 建议与未决项
| 分类 | 当前记录 |
| --- | --- |
| 建议、非已确定 | 北京时间业务日期、补卡范围/连续修复规则、首次及3/7/14/21/28解锁、月目标、软时间3+1+1/2+3；个人服务器小规模单体 |
| 硬件待核验 | Mac A2251/16GB/512GB，用户记2019但型号通常2020 Intel13英寸四雷雳；关于本机需核对；iPhone14/15Pro，iPad A1876（2018 12.9三代A12X） |
| 系统/工具待核验 | Mac/iOS/iPadOS/Xcode/签名团队/最低系统；uni-app x/HBuilderX/UTS版本、编译模式和四端实际支持；不建议第一版换设备 |
| 教材/素材待确认 | 清华准确版、上下册/ISBN/当前课次与许可；扩展原创或授权，国外课程只是参考候选 |
| 账户/供应商待实测 | DeepSeek是否API余额/合法凭据；STT/TTS、腾讯/讯飞专业评测、自由表达能力、英语音色权益、儿童授权/预算 |
| 服务设计待确认 | 数据库、登录/恢复、账号数据区域、录音期限/预算/限额、备份保护/删除残留期限 |
| 项目/发布待确认 | 三仓库名/归属/路径、个人服务器规格/域名/TLS/备份/运维、发布渠道与平台签名 |
| 不是待选项 | SwiftUI、Python+FastAPI+LangGraph、uni-app x和三仓库已经确认，不能重新写成TS建议或两仓库方案 |

## 5. 已实际完成与未完成验证
历史规范初稿为199/228行，后续补充命名及审阅已增加正文，旧数字不能作为当前行数。2026-10-11主聊天取得12文件完整创建/修改补丁，按时间顺序重放全部上下文，无失败；核验源文本引用、结构与行数，最终计数见DocumentationAudit.md。apply_patch成功及再次上下文更新不能替代独立落盘字节检查。
本窗口对十theme的正文/图标×四表面、主按钮/highlight/selection/状态、link/focus/border/divider、disabled、progress等720项角色配对按WCAG sRGB公式断言，失败0；包含重复角色复算，不代表720种独立颜色。普通字阈值4.5/控件3，主按钮#14243B字对accent6.81–11.14；不用白字浅色按钮。来源主聊天独立258项核验失败0，口径不同，不相加成“978项独立测试”。
scrim/shadow仅装饰，承载卡不透明；未宣称阴影合规，未来透明承载内容须实际底色合成重算。生成配色图、mock页面和数学计算均不等于UI/读屏/真实设备测试。
历史官方资料入口保留；本次审阅只核对报告列明的部分说明，未运行Firecrawl/Context7或验证全部最新版。前次exec与本次node_repl启动被MXC枚举锁F的BitLocker错误阻断，文件读取没有完成；发现后停止重试，不请求解锁、不再次调用会枚举F的运行入口。主动路径只G工作区/C Codex，旧文按本线程完整已知补丁精确更新，工作区规则以会话提供全文遵守，不声称重读落盘AGENTS。
未完成：落盘bytes编码/换行扫描，formatter/parser/checker实现/幂等运行，应用代码/仓库创建，后端API/数据库运行，供应商真实语音/TTS/预算测试，SwiftUI构建签名/真机，uni-app x四端编译/运行，无障碍UI，服务器部署/充值/付费服务。本次均未执行，不把接口设计或mock写成通过。
Codex文件打开工具返回queued仅确认排队，不等于已渲染预览。当前根模板29/30/29行，均低于200。此次审阅新增DocumentationAudit.md后共13文件，检查范围为完整补丁重建源文本及修正后的模型，未独立重读落盘字节。主聊天本次一次限定G/C的读取尝试仍被MXC枚举锁F阻断，未读到目标；未再重试、未要求解锁。

## 6. 文档同步清单

2026-10-11用户明确要求删除刚新增的三份重复目标任务书，保留现有实施/需求/技术/规范作为执行依据，启动时使用简短分角色引导词。已删除对应文件并清理导航引用，恢复13文件；宿主PowerShell限定三个完整路径并确认均不存在。未启动目标、创建开发窗口/源码仓库或部署；跨端当前没有单独实施细则，引导词仅引用实际存在的权威文档。
| 文件 | 本次版本/角色 |
| --- | --- |
| README.md | 规划v0.6，框架/架构/栈/样式、三环境携带清单、建议目录、13文件导航与根引导分发，已移除重复任务书引用 |
| ClientContext.md | 1.1，2026-10-11用户要求将上述方案写入文档：客户端来源/版本、可选安装实例、请求/任务追踪、统计与信任边界已纳入；新增headers保持可选并兼容EC-API-0.1；尚未实现或实测 |
| 命名确认 | 2026-10-11用户确认按建议：两客户端普通标识符统一lowerCamelCase、类型/组件UpperCamelCase；Python保留语言惯例；已更新两主规范，点分token为说明映射而非代码变量 |
| ProductRequirements.md | v0.4，三平台语义、主题设置、原业务规则和扩展验收 |
| TechnicalDesign.md | 设计v0.4，三仓库/模块/adapter/主题本地存储/内部状态映射，API仍EC-API-0.1 |
| SwiftUIImplementation.md | v0.4，Mac原生执行边界、主题/组件/编码/验收，携带事实文件 |
| BackendImplementation.md | v0.4，Python/FastAPI/LangGraph模块、状态/编码、三消费者协作，主题不加server API |
| ProjectEngineeringStandard.md | 1.1，项目完整规范和十套tokens，保存于本目录 |
| ../standards/GeneralEngineeringStandard.md | 1.1，可独立复用规范、具名project profile覆盖 |
| ProjectFacts.md | 1.3，事实、来源、建议/未决/证据及重复任务书删除记录 |
| RepositoryGuides/SwiftUI/AGENTS.md | 模板1.0，29行，仅未来Mac仓库根引导，未创建源码仓库 |
| RepositoryGuides/Backend/AGENTS.md | 模板1.0，30行，仅未来Python仓库根引导，未创建源码仓库 |
| RepositoryGuides/CrossPlatform/AGENTS.md | 模板1.0，29行，仅未来跨端仓库根引导，未创建源码仓库 |

| DocumentationAudit.md | 1.0，本次13文件审阅范围、修正、接口冻结缺口与实际验证限制 |

两份规范与需求/技术/实施正文已同步；删除三份重复任务书后当前共13文件。现有G工作区AGENTS未改，未来根模板仅说明，移植按README映射随库docs并核对链接，不复制各自演变正文、不添加公共仓库。后续变更先记事实/决策，再同步schema与受影响文档；记录不存凭据/儿童录音。

本次审阅已修正：Mac路径、跨端编码/凭据存储、离线缓存前提、全skipped无可用评价、稳定奖励去重键、multipart摘要、LangGraph隐私、记录过期与重复清单。登录/数据库/版本/预算等仍未选定；最终录音选择、课程/已有Plan读取及同步快照等schema待细化，不冒充已冻结。2026-10-11核对LangGraph持久化与FastAPI CORS官方说明；uni录音官方页直接读取超时，搜索返回兼容矩阵与Web插件说明，未实测。其他历史来源不因本次审阅自动视作最新版验证。

## 7. 官方来源与适用边界
- 编码：[PEP8](https://peps.python.org/pep-0008/)、[PEP257](https://peps.python.org/pep-0257/)、[Swift API design](https://www.swift.org/documentation/api-design-guidelines/)、[EditorConfig](https://editorconfig.org/)；用户type2/function1覆盖默认，不能假官方默认等于本规范。
- 工具：[Ruff](https://docs.astral.sh/ruff/formatter/)、[Prettier](https://prettier.io/docs/options)、[swift-format](https://github.com/swiftlang/swift-format/blob/main/Documentation/Configuration.md)、[SwiftLint](https://realm.github.io/SwiftLint/rule-directory.html)；其原生长度/空行/语法能力不等于定制门禁，尚未工程验证。
- 后端：[FastAPI模块](https://fastapi.tiangolo.com/tutorial/bigger-applications/)、[BackgroundTasks](https://fastapi.tiangolo.com/tutorial/background-tasks/)、[LangGraph persistence](https://docs.langchain.com/oss/python/langgraph/persistence)；调度/业务DB/幂等仍须自身落实。
- 跨端：[uni-app x CSS](https://doc.dcloud.net.cn/uni-app-x/css/)、[组件](https://doc.dcloud.net.cn/uni-app-x/vue/component.html)、[RecorderManager](https://doc.dcloud.net.cn/uni-app-x/api/get-recorder-manager.html)、[原生鸿蒙](https://doc.dcloud.net.cn/uni-app-x/app-harmony/)；Web录音独立，版本/编译模式需pin与四端验证。
- 配色：[WCAG文字](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum)、[非文字](https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast)；提供数学判据，不能替UI/设备验收。
- 云端：[DeepSeek](https://api-docs.deepseek.com/)、[Kimi平台](https://platform.moonshot.cn/docs)、[腾讯专业评测](https://cloud.tencent.com/document/product/884)、[讯飞](https://www.xfyun.cn/)；选型/账户/真实质量未完成。MeteorVoice只读参考链接与限制见技术设计来源章节，不改其文件。
