# 英语练习打卡项目工程规范

命名补充（2026-10-11用户确认，优先于本文旧示例）：SwiftUI与uni-app x的变量、属性、参数、函数、方法、事件、配置字段与常量统一lowerCamelCase，如currentTheme、submitRecording、textPrimary、maximumRecordingDuration；类/结构体/枚举/协议/类型及类型或组件文件基名用UpperCamelCase，如PracticeSession.swift、PracticeCard.uvue。Swift枚举case用lowerCamelCase。Python变量/参数/函数/方法/模块用snake_case，类型用PascalCase、模块常量用UPPER_SNAKE_CASE。JSON API字段保持camelCase，Python通过schema alias映射，不各自改字段；同概念保持相同词义。框架固定名称、HTTP headers、标准可观测性属性、既有稳定协议枚举值保留协议要求。主题表中的text.primary/icon.primary等点分写法仅是角色分类说明，不是代码变量或新增序列化键；客户端主题属性统一textPrimary/iconPrimary，任何原点分符号在实施前映射到唯一camelCase schema，禁止两套键并存。既有SkyLight等主题ID是稳定协议值，本次不重命名。
版本：1.1；日期：2026-10-11；状态：用户已确认架构与设计规则，工程实现/平台验证未完成；本次审阅修正见DocumentationAudit.md，行数以当前源文本核验为准。
本文件是项目当前工程权威；[通用工程规范](./GeneralEngineeringStandard.md) 是完整编码/模块/组件/状态基线，[项目事实](../planning/ProjectFacts.md) 记录决定与未验证范围。两规范均可独立审阅；实施携带规范、事实和EC-API-0.1契约，仓库根入口/随库docs映射见README。旧文架构/栈/主题冲突以本文件为准，原业务规则/接口保留，不擅改API。
本次只更新文档：不开发应用、不新建 Git 仓库、不安装工具、不付费调用、不充值、不部署、不创建其他聊天。主动文件访问限 G 工作区及 C Codex 目录；不调用会枚举 F 的运行入口，无须解锁。未来 Mac/服务器路径按各自环境确认，不能机械套用本次 Windows G/C 限制。

## 1. 已确认架构与平台
| 仓库职责 | 技术与开发位置 | 边界 |
| --- | --- | --- |
| Apple 原生客户端 | SwiftUI；Mac 编译/签名/真机 | iPhone/iPad 原生，不换架构，不与 uvue 共源码 |
| 后端 | Python + FastAPI + LangGraph；Windows 开发，未来个人服务器 | 云端 AI 统一入口，单体部署，可独立 worker；不换 TS/Mastra |
| 跨端客户端 | uni-app x / UTS / uvue；Windows 开发 | 微信小程序、Web、Android、原生 HarmonyOS NEXT；不是 Taro，不以 Android APK 代表纯鸿蒙 |

三个仓库名与路径、Python/DB/uni-app x/HBuilderX/UTS 编译模式/版本、服务器和认证未全部确认，不创建仓库来猜。uni-app x 各端编译/运行能力须按固定版本实测，不能假定任意 JS 库四端可用；[HarmonyOS NEXT 官方说明](https://doc.dcloud.net.cn/uni-app-x/app-harmony/) 为核对入口。
Mac A2251、16GB/512GB，用户记为 2019 年，通常对应 2020 年 Intel 13 英寸四雷雳机型，需关于本机确认；iPhone 14、15 Pro；iPad A1876（2018 年 12.9 英寸第三代 A12X）。系统/Xcode 版本未核对，不凭空定最低版本，不要求换设备；Windows 不能代称 SwiftUI 编译通过。
共同共享：API/错误码/规则、语义 tokens、许可素材、组件输入输出/状态与交互；SwiftUI 与 uvue 分别实现源码。课程/打卡/奖励唯一权威后端，客户端不各自重写算法。

## 2. 产品约束与需求保留
家长确认清华版二年级教材版本、上下册/ISBN、当前已学范围与合法素材。每日新课/复习/没课或未知；新课建议下一课但家长确认才推进，其他模式不自动推进。趣味题限已学范围，同日基础计划固定；国外课程仅参考，不内置未授权整套教材。
每天目标至少 5 分钟，由多道短题组成；不连续录五分钟、不强制单题录满、不以秒数/AI 高分/评价成功阻挡基础完成打卡。原 3+1+1 / 2+3 分配是可调整预算；慢/快节奏由实际任务控制，不能在首版恢复自动判停。
全 AI 云端经后端，完整录音结束后上传；无端侧模型、流式、实时字幕、实时对话、抢话/打断、自主 agent。跟读音频+参考句专业评发音，不重复语法评分；自由表达 STT 保留原话→文字语法/用词，发音另评。文本模型不能从转写判断发音；噪声/不确定识别不能算语法错误，无置信度字段不造百分比。
DeepSeek 为文本候选；专业评测腾讯/讯飞与 STT/TTS 尚需真实样本和账户验证；豆包首期不接；Kimi 会员不是 API 余额。孩子一次一个关键改进点，家长可看细节；失败/部分成功仍能打卡。
离线草稿/录音/待同步持久化，联网恢复、跨设备 backend 权威，重复日期只发一次奖。targetDate 与真实确认/client 声明时间分离，补卡保留事实；建议北京时间，规则和补卡范围上线前确认。累计与连续分开，断签不丢累计收藏。
坦克收藏馆每日零件/徽章、累计历史坦克、月度涂装/展台；首次及 3/7/14/21/28 为可配建议。保留原始历史型号名称与来源事实，原创/合法插画统一美化，不变造型号、不提供武器操作，无抽卡/战斗/多币种。奖励确认保存后才播放，离线为暂存展示。
导出 CSV/PDF 报告不同于可恢复备份；备份含记录/反馈/进度/奖励证据/选择保留录音，先预览再导入去重恢复。录音保留/删除由家长选择；原音至少保留至评测终态与有界重试窗口。云端上传、供应商残留/备份轮换如实说明。

离线与录音存储边界、最终录音选择/同步快照等冻结缺口以TechnicalDesign.md第2节和第5.6节为准。所有skipped无可用结果不算评价成功，不影响合法打卡；规则升版不得重新授予同一逻辑奖励。checkpoint/cache亦受录音与转写保留/删除策略管理，不能只删业务DB或音频文件。

## 3. 项目组织与后端职责
按 accounts/children/courses/practice/evaluation/check_ins/rewards/exports 等业务模块组织；包名 snake_case，不要把整个后端分成无业务归属的巨型 routers/services/utils。每个模块按需求分 api、application、rules/state、repository、workflow/nodes、providers、基础设施，少量模块可合文件，职责不混。
| 层 | 明确职责 |
| --- | --- |
| FastAPI 路由 | 身份/输入 DTO、调用用例、HTTP/错误码映射；不直接业务 SQL 或厂商请求 |
| 应用服务 | 用例编排、事务边界、预算/权限和幂等协调；DI 注入 |
| 规则/状态 | 计划、打卡、奖励、转移合法性；可测试，不依赖 UI/外部 API |
| 数据访问 | repository、事务/唯一约束/revision、迁移、租约条件更新 |
| LangGraph workflow/node | 有类型输入输出的评价步骤/条件分支/checkpoint；不当账号/打卡 DB |
| 供应商 adapter | 原音/文本请求转换、超时、真实字段映射、调用记录；不输出伪证据 |
| 基础设施 | 配置、密钥、日志脱敏、文件/转码、执行器、时钟/连接、指标 |

[FastAPI 模块化](https://fastapi.tiangolo.com/tutorial/bigger-applications/) 是组织能力参考；[BackgroundTasks](https://fastapi.tiangolo.com/tutorial/background-tasks/) 不替代持久化任务/崩溃恢复。数据库未定，迁移工具如 Alembic 根据选型固定；不无必要微服务/Kafka，自建模型禁用。
上传真实校验编码/体积/时长/sha256/归属，保留原始文件，受限转码供厂商使用。auth、TLS、大小/次数/并发/费用硬上限、幂等、错误码、输入输出类型、配置管理与脱敏日志必须实现。密钥只在后端保护配置，客户端只有 App 会话凭据。供应商与模拟分层，不能用 mock 冒充实测。

## 4. 三套状态与 LangGraph
业务打卡/奖励、后端评价任务、客户端录音/上传分别状态机，不因评价失败取消合法打卡。LangGraph [persistence](https://docs.langchain.com/oss/python/langgraph/persistence) 保存 checkpoint，不替代调度器/业务数据库/去重/安全；不可宣称 exactly-once。
| 后端内部状态 | 合法后继 | 限制 |
| --- | --- | --- |
| queued | running/cancelled | 领取租约且 revision 匹配 |
| running | retry_wait/succeeded/partial_success/failed/cancelled | 每组件结果和预算调用记录先持久化 |
| retry_wait | queued/failed/cancelled | nextRetryAt 到期且剩余上限，失败步骤重试 |
| succeeded/partial_success/failed | 无自动后继 | 显式 retry 创建受控新执行版本，不改既有结果历史 |
| cancelled | 无 | 迟到结果不得恢复任务或发奖 |

工作池/worker 用租约所有者、expiresAt、心跳、executionVersion 和条件更新；重启回收过期租约，按已保存步骤/供应商调用记录恢复。取消标记在调用前后检查；外部不能取消也要防回包写入。重试有时间/次数/费用上限，结果未知需 reconcile，不盲重复付费；成功步骤结果可复用且其音频/模型版本必须匹配。
允许组件先返，不等全成功才展示；语法依赖 usable/人工确认原话，专业发音可并行。不支持能力为 skipped+reason，无证据不输出分数。失败步骤单独重试，不重复成功 STT/TTS 等付费请求。checkpoint 保存节点状态不保证外部调用仅一次，供应商幂等只按其真实能力使用。
**接口保持 EC-API-0.1 不变**：内部 partial_success 映射原契约 partial；retry_wait 映射 queued，保留 component reason/retryable 和原 nextPollAfterMs；不要向旧客户端发新 enum。组件早返仍使用原 components/results。若将来要暴露新状态，先版本化提案、两端/三消费者确认后变更，不能在本次文档暗改接口。
客户端示例状态 idle/recording/interrupted/recorded/queued/uploading/confirmed/error；课程/奖励状态独立，不假波形、假 AI percent 或动画结束才确认。离线重放稳定 ID，对象版本冲突需显式合并，不按设备时间静默覆盖。

## 5. 前端共用组件与平台隔离
页面只组合业务用例、viewmodel/state 与组件。平台 adapter 封装 recorder、audio playback、file、permission、login/session、theme storage；条件编译集中在 adapter，不能每页散平台 if。后端规则唯一，前端只消费契约状态与 summary。
[uni-app x RecorderManager](https://doc.dcloud.net.cn/uni-app-x/api/get-recorder-manager.html) 内置能力不支持 Web，Web 必须单独录音实现，并验证浏览器权限、编码与文件上传；不写四端 RecorderManager 通用假实现。纯鸿蒙独立验证文件/麦克风/音频能力，不拿 Android 运行替代。
样式按固定编译模式共同子集 Flex/绝对定位，[CSS 官方说明](https://doc.dcloud.net.cn/uni-app-x/css/) 与 [组件说明](https://doc.dcloud.net.cn/uni-app-x/vue/component.html) 为核对入口；DOM、任意 CSS、Vue Transition 不当四端能力。插件 [uni_modules](https://doc.dcloud.net.cn/uni-app-x/plugin/uni_modules) 核对目标端支持，不假设 npm JS 任意库可用。
| 组件 | 输入/输出与状态合同 |
| --- | --- |
| Button | kind/size/disabled/loading/action，稳定 label、防连点、focus/pressed/禁用反馈 |
| Dialog/Sheet | open/title/content/actions/closePolicy，焦点恢复、键盘避让、安全区/滚动 |
| Toast/Banner | semantic/message/action/duration，严重错误持续 banner；读屏、主题实时更新 |
| Form/Input | value/label/required/error/keyboard，验证时机、下一焦点/提交，禁用/错误态 |
| List/Pagination | items/loading/empty/error/retry/page 或 cursor，mobile load more、desktop 分页 |
| Card/Container | padding/maxWidth/layout，点击态与静态区分，窄屏/两栏/安全区 |
| Recorder | state/duration/record/play/stop/retry，真实时长、来电中断、权限/磁盘错误 |
| Feedback | pending/partial/uncertain/ready/error，儿童一个重点，家长展开证据/重试 |
| Calendar | targetDate/confirmedAt/makeup/selected，日期来源、图形+文字标识 |
| Reward | pending/confirmed/locked/item/nextTarget，保存后播，可跳过/静态降级 |

同名组件在 SwiftUI 与 uvue 各有实现，不共源码；共享行为 schema 与素材 ID，不要求平台 UI 完全像素相同。禁止万能 globalVM/common utils；第二次同一规则抽到后端或明确纯映射共享语义，约 10 行实质重复审阅。

## 6. 主题：完整十套值与消费规则
用户已确认暖白+浅蓝 B 默认，学习页简洁、解锁精彩。设置配色组五选一，模式 system/light/dark；system 跟随设备，默认组显示名 Sky（存储键 sky），light 为晴空蓝，dark 为午夜晴空。按设备存储 group/mode，离线可切，不强制跨设备同步。切换时已打开弹层、toast、表单、录音与收藏同时更新。
以下表 + 固定 L/D 组合规则完整定义所有 tokens；主题 ID 采用具名 project profile 覆盖为 UpperCamelCase（SkyLight 等），设备存储 group 键 lowerCamelCase：sky/mist/lavender/peach/lemon，mode 为 system/light/dark；上文 Sky 指默认配色组显示名，不是存储值。色值皆不透明 #RRGGBB，除明确 scrim/shadow。页面不得硬编码主题色；两客户端各自映射同一 schema，所有角色消费，不留未定义 fallback。
| ID / 名称 | accent | page | card | elevated | input | 组合 |
| --- | --- | --- | --- | --- | --- | --- |
| SkyLight / 晴空蓝 | #87CEFA | #FAF8F3 | #FFFFFF | #FFFFFF | #F0F3F8 | L |
| SkyDark / 午夜晴空 | #87CEFA | #101827 | #192338 | #22304A | #141E30 | D |
| MistLight / 雾蓝晨光 | #B8D4F0 | #F7F9FC | #FFFFFF | #FFFFFF | #EEF3F9 | L |
| MistDark / 深海星光 | #8BAAF5 | #111A30 | #1B2740 | #25324D | #152139 | D |
| LavenderLight / 薰衣草 | #C4B5FD | #FAF8FF | #FFFFFF | #FFFFFF | #F1EDFA | L |
| LavenderDark / 紫夜银河 | #B9A0FF | #1B162A | #272038 | #332944 | #201B31 | D |
| PeachLight / 蜜桃奶油 | #FDBA9A | #FFF8F2 | #FFFFFF | #FFFFFF | #F9EEE5 | L |
| PeachDark / 琥珀夜色 | #F2BB67 | #211B16 | #30271F | #3C3026 | #29211B | D |
| LemonLight / 柠檬晴日 | #F4D96B | #FFFCF1 | #FFFFFF | #FFFFFF | #F5F0DC | L |
| LemonDark / 石墨冰蓝 | #A7C7E7 | #181C22 | #252B33 | #303741 | #1F252D | D |

| 语义 token | L 组合 | D 组合 |
| --- | --- | --- |
| text.primary / icon.primary | #14243B | #F2F5FC |
| text.secondary / icon.secondary | #405168 | #D1D9E8 |
| text.tertiary / icon.tertiary | #526078 | #AAB8CD |
| button.primary.bg/fg | accent / #14243B | accent / #14243B |
| button.primary.border | #14243B | #AAB8CD（对外部底色形成边界） |
| button.secondary.bg/fg/border | card / text.primary / #526078 | card / text.primary / #AAB8CD |
| link | #244F85（下划线/可识别行为） | #B8D4F0（下划线） |
| highlight.bg/fg | accent / #14243B | accent / #14243B |
| selection.bg/fg/border | accent / #14243B / #14243B | accent / #14243B / #14243B |
| focus.border | #244F85 | accent |
| hover.bg/fg/border | input / text.primary / #526078 | input / text.primary / #AAB8CD |
| pressed.bg/fg/border | input / text.primary / #14243B | input / text.primary / #F2F5FC |
| disabled.bg/fg/icon/border | #E4E7ED / #526078 / #526078 / #526078 | #2A3446 / #AAB8CD / #AAB8CD / #AAB8CD |
| border / divider | #526078 | #AAB8CD |
| scrim | #00000080 | #00000080 |
| shadow | #14243B26 | #00000066 |
| success.bg/fg/icon | #E8F5EE / #145238 / #145238 | #14392A / #A6E7C4 / #A6E7C4 |
| warning.bg/fg/icon | #FFF0CF / #624300 / #624300 | #3D3015 / #F7D58A / #F7D58A |
| error.bg/fg/icon | #FDECEF / #8B2034 / #8B2034 | #40202A / #FFB4C0 / #FFB4C0 |
| info.bg/fg/icon | #EAF2FC / #244F85 / #244F85 | #1B304C / #B8D4F0 / #B8D4F0 |

状态消费明确：主按钮 hover/pressed 保持 accent/#14243B，hover 加控件边界、pressed 轻缩放/静态边界变化；不把普通 hover input 背景覆盖主按钮。普通次按钮/表单使用 hover/pressed 表行，disabled 优先且无操作。focus 为外围实线环，与控件外部底色比较；selection.border 在 accent 选中块上与 fill 比较。主题切换不依赖旧计算缓存。
| 领域角色 | 固定组合规则（十套均定义） |
| --- | --- |
| recording.active.bg/fg/icon/border | error.bg / error.fg / error.icon / error.fg；idle 为 input/text.primary/border；时长和录音标识文字可见 |
| progress.track/fill/border/label | input / link（L）或 accent（D） / border / text.primary；不确定评价只状态文字+无定值加载 |
| calendar.cell.bg/fg | card/text.primary；selected 为 selection；today 外环 focus；complete 为 success.bg/fg/icon；makeup 为 info + “补” |
| reward.surface/title/subtitle | card/text.primary/text.secondary；badge 为 highlight；pending 为 info；locked 为 input/text.tertiary + 剪影/文字 |
| input.error/selection/focus | error.fg 实线边框与错误文字；selection 使用 selection；focus 使用 focus，不仅颜色 |
| dialog/toast/banner | 不透明 elevated 或 status.bg + 对应 fg/icon，scrim 后面无承载内容，主题实时生效 |

border/divider 对所有常规表面必须可见；图像装饰不冒充状态边界。浅蓝 accent 与浅背景本身可能 <3:1，主按钮使用深色边框，不能宣称浅蓝 fill 自身达到控件边界标准。主按钮禁止白字：这些 accent 对白字只有约 1.40–2.29，对 #14243B 则 6.81–11.14。不可把低对比浅蓝当正文链接。
scrim/shadow 为装饰，无文字/图标放在透明层直接承载；其后的对话卡不透明，合规声明只针对卡片。若改成透明卡或上面放文字，必须按实际底色 alpha 合成重算；不对当前阴影宣称可访问性达标。

## 7. 实际颜色计算与限制
2026-10-11 在 functions.exec 纯 JS 按 WCAG sRGB 线性化与相对亮度公式计算，未 shell/未 UI/未真机。所有主要/次要/三级文字与图标逐一对 page/card/elevated/input；主按钮/highlight/selection/hover/pressed 对 accent；link、focus、边界对表面；disabled；四种 status fg/icon/border 对各自 bg、progress 等共720项角色配对断言无失败（重复角色明确复算，不代表720种不同色）。必要文字与控件按各自阈值验证。
表为实际最小值（显示四舍五入，断言用未舍入数），T=三文字角色×四表面，P=accent/主按钮字，Link=四表面，Focus=四表面，Border=四表面及 disabled，Dis=禁用字，Status=四状态各配对最小。
| ID | T >=4.5 | P >=4.5 | Link >=4.5 | Focus >=3 | Border >=3 | Dis | Status >=4.5 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| SkyLight | 5.72 | 9.10 | 7.46 | 7.46 | 5.13 | 5.13 | 7.35 |
| SkyDark | 6.57 | 9.10 | 8.63 | 7.70 | 6.23 | 6.23 | 8.60 |
| MistLight | 5.70 | 10.19 | 7.43 | 7.43 | 5.13 | 5.13 | 7.35 |
| MistDark | 6.36 | 6.81 | 8.35 | 5.58 | 6.23 | 6.23 | 8.60 |
| LavenderLight | 5.52 | 8.46 | 7.20 | 7.20 | 5.13 | 5.13 | 7.35 |
| LavenderDark | 6.78 | 7.09 | 8.90 | 6.19 | 6.23 | 6.23 | 8.60 |
| PeachLight | 5.57 | 9.42 | 7.26 | 7.26 | 5.13 | 5.13 | 7.35 |
| PeachDark | 6.36 | 8.98 | 8.35 | 7.35 | 6.23 | 6.23 | 8.60 |
| LemonLight | 5.56 | 11.14 | 7.26 | 7.26 | 5.13 | 5.13 | 7.35 |
| LemonDark | 5.97 | 8.90 | 7.84 | 6.84 | 5.97 | 6.23 | 8.60 |
L status success/warning/error/info 实算 8.16/8.02/7.83/7.35；D 9.01/9.09/8.60/8.71。普通 hover/pressed 背景是 input，文字在 T 范围；主按钮 state 保持 P；secondary 是 card/text.primary；选中边框是 P；progress fill 与 input 最低 L 7.20、D 5.58，均 >=3。
主按钮 L 深边框对外部四表面 >=T 的 text.primary 项且对 accent 为 P；D border 对外部表面已在 Border 项。D border 与 accent 内侧未宣称 >=3，保证是外部边界可识别。error/recording 边框在 error.bg 上采用 status fg（Status 项）；图标与文字同色。focus 不依赖 shadow。
普通正文 >=4.5、大字 >=3、必要控件 >=3；本表文字都按 >=4.5，未利用“大字例外”。disabled 在标准允许例外，本值仍 >=5.13。颜色不能唯一标识，选中、补卡、录音、错误、锁定都有形状/文字/语义状态。真实设备还需检查字体、布局、图像、读屏、透明叠加及操作状态；未声称已过。
计算公式：c=hex/255；c<=0.04045 时 c/12.92，否则 ((c+0.055)/1.055)^2.4；L=0.2126R+0.7152G+0.0722B；ratio=(maxL+0.05)/(minL+0.05)。[WCAG 文字](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum)、[控件](https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast) 为判据，不是平台 build 结果。

## 8. 样式和动画基线
| 维度 | 确认基线 |
| --- | --- |
| typography | title 28 / section 22 / body 17 / helper 14 / english 24 逻辑单位；Swift pt、各端可用逻辑 CSS/框架单位映射，支持动态字号，不能统一物理 px |
| spacing | 4/8/12/16/24/32，语义 spacing token |
| radius | button 12 / card 20 / sheet 24；不为凑样式遍地硬编码 |
| touch | 儿童主操作至少 48 逻辑单位；扩大 hit area 不覆盖其他操作 |
| alignment | 文本/表单/标题左对齐；录音核心/奖励主体居中 |
| layout | mobile 单列，tablet/desktop 限宽可两栏；建议 reading 720、wide 1120，按实际端字号/安全区验证后定，不假响应已完成 |
| animation | click 120–180ms，转场 200–300ms，reward 1–2s 可跳过；reduced motion 静态确认；低性能降级，后台停视觉动画 |

状态持久化后播奖励，动画不发奖；录音时长来自真实 session/时间，不假波形；评价不假 percent。主题切换保证弹层/键盘焦点/安全区，动态字号不截断英文、错误和关键按钮；列表 mobile load more、桌面分页共享游标/页语义。[Apple layout](https://developer.apple.com/design/human-interface-guidelines/layout)、[Reduced Motion](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/reduced-motion-evaluation-criteria) 为 Apple 行为参考，其他端使用实际可用能力。

## 9. 项目编码与规模门禁
本节给独立执行摘要，完整规则/合法示例在通用规范。所有手写 source 文件有多行职责头，公共 API/复杂逻辑多行说明；Python 真 docstring triple-double + Args/Returns/Raises 按需，Swift 多行 /// + 内部 /* */，UTS /** */、CSS /* */、template <!-- -->、YAML/PS/shell 多行 #、SQL /* */。JSON 严格不能注释，用伴随说明+schema 具名例外；单行 MARK/directive 例外。prompt/SQL 字符串计代码，不能藏废代码。
UTF-8 无 BOM、LF、末尾一个 newline、无尾随 space、无 tab（Makefile 具名语法例外）；Python/Swift/PS 4 空格，UTS/uvue/CSS/JSON/YAML 2；续行一层，不水平空格对齐。宽度目标100/硬120，长 URL/字面量单项例外；不压一行多语句。
声明“空格”是空行：类型/类间恰好2、函数/方法间1、类型与函数边界优先2，无超过2；注释/装饰器附着声明；imports 分组1空行。Python 有意覆盖 PEP8 顶层函数2为空行1。[PEP8](https://peps.python.org/pep-0008/)、[PEP257](https://peps.python.org/pep-0257/) 是默认参考，用户选择优先。
括号无内空格，逗号后1、二元运算符两边1；Python dict/注解冒号后1，简单 slice 无额外空格，无注解默认/kwarg 为 x=1、有注解 x: int = 1；Swift/UTS braces 同行、else/catch 同行。JSON 无 trailing comma，Python/UTS 仅语法支持处 trailing comma；长 import Python 括号竖列、UTS 花括号竖列、Swift 一模块一行；长组件属性每行一个。UTS 分号/引号按固定编译模式验证，不假 formatter 已支持。
| 分类 | file 提醒/硬限 |
| --- | --- |
| pages SwiftUI/uvue | 200/300 |
| shared UI | 150/200 |
| state/viewmodel/service/repository/provider | 200/300 |
| schema/model | 150/250 |
| state-machine/graph node/workflow | 120/200 |
| utils/extensions/tokens/CSS | 120/200 |
| 手写 config/build/ops | 150/250 |
| tests | 250/350 |
| docs | 300/500 |
| 未知手写 | 200/300 |

文件/类型/函数门禁同时适用；Markdown中文正文/表格按500有效行限制，不机械套代码120字符宽度，fenced代码仍按代码规则。具体空行边界及最小工具验证见通用规范。
函数30提醒/50硬限，类型150/200（跨 Swift extension 合计），SwiftUI body<=60；业务控制嵌套<=3，UI 布局不算控制流；复杂度<=10，不是调用栈3。注释不计、普通空行计、inline code+comment计1，block内部空白不计，EOF不虚增；条件编译指令计有效代码。
语言 tokenizer/AST/可靠 parser 统计，不用正则剥字符串；Python 仅 AST 真 docstring 除外；手写 migrations/tests 不全部排除，生成/第三方/lock 具名排除。md 正文及 fenced 示例计有效行。禁止删除注释/压行/无义 forwarders 躲限制，超提醒审阅，硬限需批准例外。
命名：工作区新增大驼峰、隐藏规则继承 G AGENTS；仓库 Python snake_case.py、Swift UpperCamelCase.swift、组件 UpperCamelCase.uvue/easycom约定、PowerShell Verb-Noun.ps1，框架 App.uvue/pages.json/manifest.json/uni_modules 保留。导入与调用引用、大小写/相对路径同步更新；禁止万能 Utils/Common/globalVM、数字临时名；锁定依赖版本，按目标核验 API。

## 10. 工具、实施与验收
流水线唯一：固定基准 formatter → AST 安全空行规范化 → custom checker → lint/类型/测试；整体两次输出相同验证幂等，不同时用原始 formatter --check 当最终强门禁。[Ruff](https://docs.astral.sh/ruff/formatter/) 顶层空行、[Prettier](https://prettier.io/docs/options) 折空行可能与用户规则冲突；UTS/uvue parser 支持须验证，不假称插件可用。
Swift swift-format maximumBlankLines=2 仅上限，不能保证恰好2；SwiftLint 原生长度不等于去注释但算普通 blank 的口径，补 custom checker；Python 类型用选定工具、迁移用所选 DB 工具。本文没有实现检查器，也没有跑 formatter/build；禁止把这些设计门禁写成已通过。
Swift 无 force unwrap/try? 吞失败，main actor/UI 异步取消/任务生命周期按最低版本实际实现；Observation 或 ObservableObject 在系统核对后选，不假版本兼容。各调用层实际职责，DI 明确输入输出和副作用。
| 阶段/环境 | 验收重点与证据 |
| --- | --- |
| 规范/契约 | profile、版本/哈希、parser fixture/统计口径、pipeline 幂等、例外与实际运行记录 |
| 后端真实本地 | 类型/权限/输入、真实事务重复竞态、任务租约/恢复/取消迟到/费用边界、备份恢复/删除 |
| SwiftUI Mac | Xcode/系统/签名、iPhone14/15Pro/iPad A1876 构建和真机录音/中断/离线/布局/主题 |
| uni-app x 各端 | 固定版本/编译模式，小程序/Web/Android/HarmonyOS NEXT 分别录音/权限/文件/login/主题/适配；Web独立录音 |
| 真实供应商 | 家长授权同批匿名儿童样本+人工参考，误报/漏判/原话/噪声/稳定性/等待分布/实际费用；mock只编排 |
| 用户流程 | 新课确认、不越学、基础完成不依赖评测、补卡/跨日/跨设备不双发奖，离线恢复，报告与备份区别 |
| 主题/UI | 十套×主要组件状态/弹层同步/动态字号/焦点键盘安全区/对比与读屏，减少动态效果可跳过 |
| 发布准备 | 单体/worker方案、个人服务器配置/备份恢复/健康/回滚；另行授权才部署，不自动购买 |

API 仍为 EC-API-0.1，唯一权威在 [TechnicalDesign.md](../planning/TechnicalDesign.md) 第5节，后端 canonical schema、两客户端派生类型版本匹配；架构覆盖本规范，接口不自行改。不同框架不共享实现，只共享协议语义；不以跨端 mock 编译代表供应商效果。
PR 遵守各仓库 hooks/审计/CI/分支规则，描述最终问题/行为/契约/迁移/验证；例外按通用模板写路径、规则、原因、保护、责任/批准/到期/证据。没有应用实现所以本次不存在通过的 PR/build/API 测试。
旧规范来源沿用历史官方入口；本次审阅补核范围见DocumentationAudit.md，未重新核对所有依赖/厂商当前版本；规范中的用户决定与官方默认明确区分。实际保存与验证限制见 README：补丁成功确认文件和末尾内容，纯 JS 行数/主题计算已做；未独立读取落盘字节，不声称 UTF8/LF 的字节实测通过。主题 ID 与设备存储键采用本节具名 profile 覆盖，未改 EC-API-0.1。
