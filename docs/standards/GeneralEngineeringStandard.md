# 通用工程规范

命名基线补充（2026-10-11）：Swift/JS/TS/UTS的变量、属性、参数、函数、方法、事件、配置字段及常量统一lowerCamelCase；类/结构体/枚举/协议/类型及类型/组件文件基名用UpperCamelCase，Swift枚举case用lowerCamelCase。Python保留snake_case成员/模块、PascalCase类型、UPPER_SNAKE_CASE模块常量。框架固定名称、HTTP headers、标准属性与稳定协议值按其规范保留，API字段由同一契约定义，语言内部按schema alias映射。语义token采用textPrimary/iconPrimary等camelCase属性；点分名称只用于解释层级，不直接复制为变量名或另设重复键。具体语言文件命名及框架例外见后文矩阵，同概念词义必须一致。
版本：1.1；日期：2026-10-11；状态：规范文档，检查工具尚未实现或验证；当前检查范围及源文本行数见项目审阅报告，历史行数不作为当前文件计数。
本文件独立适用于未来项目。语言、平台、框架、主题数量与业务内容通过 project profile 选择，不强制 SwiftUI、uni-app x、Python、LangGraph 或任何产品。示例是格式说明，不是已验证应用代码。
英语练习项目可作为采纳示例，但本通用文件单独携带时无需该项目文档；产品、配色数量和架构由未来项目profile填写。

## 1. 采纳方式与优先级
1. 读取工作区与仓库治理文件；将本规范复制/引用到仓库，并填写下表。
2. 确认语言版本、编译模式、目标平台、canonical 契约、检查器及具名例外；不要安装工具来猜规则。
3. 先测现有格式器与自定义统计的差异，选定一条幂等流水线，再分批治理，不跨会话批量重写。
4. 新改文件执行规范；存量超限列入清单，不能通过排除整个目录假装通过。
5. 在 PR 里提供实际检查证据；尚未实现的 checker 标为待实现，不声称 lint 已覆盖全部规则。

| Profile 字段 | 项目填写内容 |
| --- | --- |
| 仓库/职责/维护者 | 仓库边界、授权路径、不能修改的项目 |
| 语言与运行环境 | 版本、最低系统、编译器/模式、目标端、实际测试端 |
| 架构 | 业务模块、公共 UI、平台 adapter、持久化、任务执行方式 |
| 契约 | canonical 文件、版本/哈希、错误码、兼容策略、变更责任 |
| 设计系统 | token schema、主题/模式、设备存储、平台映射 |
| 工具链 | formatter、lint、类型、计数/parser、测试、CI 顺序与固定版本 |
| 生命周期 | 身份、数据保留、备份/恢复、删除、费用/超时/重试 |
| 例外/验收 | 例外编号、责任人、到期条件、平台验收矩阵、未验证项 |

用户明确选择优先于技能建议与默认格式器；项目规范补充本规范，冲突处须明确列出。工作区命名不替代仓库语言约定。本文的“空格”在声明间隔要求中指**空行**，在缩进/运算符要求中指 U+0020 空格，不能混淆。

## 2. 模块、依赖和复用
按业务能力组织代码，模块内分 API/页面、应用服务、规则/状态、数据访问、工作流节点、供应商 adapter 与基础设施。小项目可共文件但职责清楚，文件超限时沿职责拆。路由只认证、校验、调用应用服务和映射响应；页面只组合业务状态与共用组件，不能堆查询、供应商逻辑和平台条件。
应用服务编排用例与事务；规则层不直接访问网络/UI；repository 负责持久化与并发；adapter 转换外部协议；基础设施提供配置、日志、时钟、连接与执行器。DI 在组合根注入，避免全局可变 service/viewmodel、隐式单例和循环依赖。每层调用必须有实际职责，不拆无意义转发器。
同一业务规则第二次出现应提取唯一实现；约 10 行实质重复触发审阅，先判断是否同一语义，不把所有相似布局硬并。共享组件稳定后抽取，拒绝万能 Utils/Common 和无限参数开关组件。
公共函数明确输入、返回、错误、取消与副作用；不使用隐式异常吞掉失败。供应商模型不能泄漏到全应用，核心类型和映射职责明确。版本锁文件提交并核验依赖/API，与当前目标平台不兼容就明示，不凭旧文档假定可用。

## 3. 命名、导入与创建
| 场景 | 规则与例子 |
| --- | --- |
| 工作区新增目录 | 遵守所属工作区；本实例 G 盘非隐藏大驼峰 Codex/EngineeringStandards，隐藏点号小驼峰/小写连字符；既有语言/历史目录不擅改 |
| 仓库/第三方目录 | 保留仓库与框架约定，node_modules、.venv、uni_modules 不改名；任务产物不散到根目录 |
| Python | 文件/模块/函数/变量 snake_case；类 UpperCamelCase；常量 UPPER_SNAKE_CASE；例如 evaluation_service.py、EvaluationService |
| Swift | 类型/文件 UpperCamelCase.swift，成员 lowerCamelCase；扩展文件如 ChildRecord+Formatting.swift，禁止用扩展逃避类型总长 |
| Vue/UTS | 共用组件 UpperCamelCase.uvue、一般成员 lowerCamelCase；easycom 与框架规定名称保留并记录；App.uvue/pages.json/manifest.json 不改 |
| 脚本/样式/配置 | PowerShell Verb-Noun.ps1；Python snake_case.py；shell/普通 web 文件 kebab-case；tokens.css；默认主题 ID/存储键 lowerCamelCase，项目 profile 可具名覆盖为主题常量 UpperCamelCase、存储键 lowerCamelCase；两类键须明确映射，不得静默混用 |
| 测试/临时文件 | test_*.py、*Tests.swift、*.spec.* 或框架规定；任务目录有用途名，不留 1.py、tmp2、final-final；测试 fixture 标来源/生成方式 |
| 路径/引用 | 模块 import 与实际目录大小写一致，禁止绝对机器路径进入应用；配置注入 API base URL，文档本地交付可用绝对路径 |

创建时先检查现有同职责模块与导出，再用实际调用点验证名称；移动后更新 import、资源路径、测试和说明，检查大小写敏感 CI。以下导入和调用相互对应，不能只重命名文件不改调用：
~~~python
"""练习应用服务的调用入口。

只编排用例；数据库实现由组合根提供。
"""
from app.practice.application_service import PracticeService

result = practice_service.complete_plan(command)  # practice_service 的类型为 PracticeService
~~~
上例 inline 注释只解释计数/引用演示；实际复杂解释用多行。Python 内部包使用清楚的绝对模块路径，不依赖修改 sys.path。Swift 一模块一行 `import Foundation`，同模块内部类型无需伪造文件 import；JS/UTS 的 `import { RecorderState } from "./recorder-state"` 必须实际导出类型并在 `state: RecorderState` 中消费，不能留下未使用导入。别名须写入编译/运行配置并各端验证。

## 4. 文本、空格与空行
所有手写文本 UTF-8 无 BOM、LF、末尾恰好一个换行、无行尾空格；禁止 tab。Makefile recipe 等语法必需 tab 是具名例外，不能全文件放开。二进制不转换。
| Profile | 基础缩进/续行 | 规则 |
| --- | --- | --- |
| Python/Swift/PowerShell | 4 空格/一层 4 空格 | 不用水平空格对齐多行字段 |
| TS/JS/UTS/uvue/template/CSS/JSON/YAML | 2 空格/一层 2 空格 | 项目如选 shell 默认 2 空格，固定配置 |
| SQL | 2 空格 | 关键字统一大写，参数绑定，SQL 字符串仍计代码长度 |

每行目标 100，硬限 120 字符；长 URL、不可安全折断的字面量以单项例外保留，不改变语义、不压同一行多语句。格式器支持的“行宽”可能是软目标，checker 另验硬限。
**声明空行**：类型/类声明间恰好 2 空行；函数/方法间恰好 1 空行；类型/类与相邻函数边界优先 2 空行。注释/装饰器/属性 wrapper 附着其声明，不插空行；任何地方不超过 2 连续空行。文件头与 imports、各导入组、普通逻辑段为 1 空行，类型边界仍优先 2。
Python 顶层函数 PEP 8 默认 2 空行，本规范有意采用用户指定 1 空行；顶层类边界 2、类方法 1。不能用 PEP 8 静默覆盖。imports 分标准库、第三方、本地，各组 1 空行，组内排序，不混执行语句。[PEP 8](https://peps.python.org/pep-0008/)
括号无内侧空格，逗号后 1 空格；一元运算符无多余空格，二元运算符两侧 1 空格；逗号/冒号前无空格。Python 字典冒号后 1，注解 `name: str`，slice 简单 `values[1:3]`、复杂切片按语法对称；无注解默认/关键字参数 `limit=5`，有注解默认 `limit: int = 5`。Swift/TS 类型冒号后 1，CSS `color: value;`，JSON `"key": "value"`。
Swift/JS/TS/UTS 左花括号跟声明同一行，`} else {`、`} catch {` 同行；Python 用冒号与缩进，不引入花括号。JS/TS 采用分号；UTS 采用目标编译器接受的分号形式并实际验证，不声称任意 TS 插件可处理 UTS。Swift/Python 不尾加分号。JSON 严格无注释、无 trailing comma；Python/JS/TS 在语法允许的多行结构保留 trailing comma，UTS 按实际编译支持验证。
长组件属性每行一个，闭合符单独行；不能把缩进或空格塞入字符串/模板改变渲染。引号不混淆：Python 默认双引号，含引号可选更清楚形式；Swift 双引号；JS/UTS 双引号；JSON 仅双引号；YAML/shell/PowerShell 根据插值与转义语义选择。不要机械替换字符串引号。

~~~python
from app.practice.models import (
    CompletionCommand,
    CompletionResult,
)


class PracticeService:
    """处理一次练习完成。

    事务由 repository 提供；本类型不调用供应商。
    """

    def complete(self, command: CompletionCommand) -> CompletionResult:
        """确认练习并返回权威结果。

        Args:
            command: 已通过输入校验的完成指令。

        Returns:
            去重后的结果。

        Raises:
            ConflictError: 计划版本已变化。
        """
        return self.repository.complete(command)

    def get_status(self, child_id: str) -> CompletionResult:
        """查询既有结果。

        不改变打卡或奖励。
        """
        return self.repository.get_status(child_id)


def build_service(repository: PracticeRepository) -> PracticeService:
    """构建服务。

    注入数据访问对象，不读取全局配置。
    """
    return PracticeService(repository)
~~~
上例类型与函数前 2 空行、方法间 1；示意类型/构造器需由项目实现，不是可运行代码。
~~~typescript
import {
  RecorderState,
  RecordingResult,
} from "./recorder-state";

/**
 * 把录音结果转换成提交指令。
 * 只转换类型，不发起网络请求。
 */
function toCommand(result: RecordingResult): RecorderState {
  return result.state;
}
~~~
Swift import 不支持把一个模块拆成竖列；Python 用括号竖列，TS/UTS 用花括号竖列，不用反斜杠续行绕规则。

## 5. 注释与文档
每个手写代码文件必须有有意义的**多行**职责头，描述边界/副作用/重要约束；公共 API、复杂状态与重试/事务逻辑必须多行注释。清楚的简单私有方法不要求逐行复述。禁止单行注释凑数量、冗余逐行翻译、废弃代码藏注释；修改行为同步注释。
| 语言 | 统一写法 |
| --- | --- |
| Python | module/type/method 真正 docstring 用 triple-double；摘要、空行、Args/Returns/Raises/副作用按适用项；内部解释连续多行 # |
| Swift | 连续多行 /// 文档块，内部 /* ... */；单行 MARK 和平台 directive 允许具名例外 |
| JS/TS/UTS | /** ... */ 职责和公共 API 文档；内部复杂逻辑同类多行块 |
| CSS/SQL | /* ... */；SQL 参数与事务意图说明，不隐藏旧查询 |
| HTML/uvue template | <!-- ... -->；script/style 分别使用其语言写法，根文件头须不破坏框架 |
| YAML/PowerShell/shell | 连续多行 #；PowerShell 可用合法 <# ... #>；shebang/编码/条件指令按语法保留 |
| JSON/锁/资产/严格机器格式 | 不能插非法注释；伴随说明文件 + schema 字段语义记录具名豁免；生成文件不伪造手写头 |

~~~swift
/// 管理录音的应用状态。
/// 网络上传由独立服务处理，取消会停止当前任务。
@MainActor
final class RecorderViewModel {
    /* 音频中断后必须由用户确认片段，
       不能把中断片段自动当成完整提交。 */
}
~~~
~~~powershell
<#
同步指定任务的报告。
只操作显式输入目录，不枚举其他盘。
#>
param(
    [string]$TaskPath
)
~~~
[PEP 257](https://peps.python.org/pep-0257/) 定义 docstring；多行 prompt/SQL/普通字符串不是 docstring，不能用它们逃避计数。条件编译 `#if`、uni 平台指令和 compiler directive 即便长得像注释仍是有效控制代码，计入代码，不删除。

## 6. 行数、复杂度与计数门禁
表中为有效行“提醒/硬限”。**注释不计，普通空白行计入**；EOF 最后换行不额外虚增一行；含代码的 inline-comment 行计 1；纯 comment block 内部空白随块排除。方法/类型按相同口径。
| 分类 | 提醒/硬限 |
| --- | --- |
| 页面 SwiftUI/uvue | 200/300 |
| shared UI | 150/200 |
| state/viewmodel/service/repository/provider | 200/300 |
| schema/model | 150/250 |
| state-machine/graph node/workflow | 120/200 |
| utils/extensions/tokens/CSS | 120/200 |
| 手写 config/build/ops | 150/250 |
| tests | 250/350 |
| docs（Markdown 正文不是注释） | 300/500 |
| 未知手写分类 | 200/300 |

方法/函数提醒 30、硬限 50；类型/类提醒 150、硬限 200，Swift 跨 extension 合并整体职责计算；SwiftUI body 硬限 60。业务控制嵌套 <=3，UI 布局容器不算业务控制层；圈复杂度 <=10，不是“调用栈最多 3”。复杂度计算按语言 AST 的决策点规则固定版本，分支/短路表达式说明口径。
超过提醒需评估拆分并记录；硬限未有有效例外则阻止合入。不压缩同行语句、不删除必要注释、不把长逻辑拆成无意义 forwarders、不以碎片 extension 躲类型限制。
checker 必须用语言 tokenizer/AST 或经过验证的 parser；禁止正则剥引号/注释。Python 只排除 AST 所识别 module/class/function 真 docstring；普通多行字符串每行计入。Swift/UTS/uvue 混合语法与条件编译须测试 parser 覆盖；解析失败报失败，不能返回零。Markdown 使用正文行统计，不把所有文字当注释；fenced 示例正文也计入，HTML 注释才按明确口径排除。
排除列表必须具名：生成文件、third-party、locks、编译产物路径及生成来源；不能排除全部 tests 或 migrations，手写迁移仍计数。JSON 无注释豁免不等于免行数。计数器需 fixture 验证字符串内注释符、docstring、inline 注释、空白/EOF、平台 directive、uvue 分区与 Swift 扩展合计。

计数边界补充：文件、类型、函数限制同时适用，页面文件允许300行不表示其中单个类型可超过200行；Swift扩展按同一类型合并计数。空行规则用于相邻声明及逻辑段，不要求在类型开/闭括号、文件起止或单个属性周围机械补两行。Markdown正文/表格/链接实行500有效行总限，长中文段落和表格不机械套代码120字符限；fenced代码示例仍执行代码规则，URL/不可断字面量列明确例外。

## 7. 格式器与检查流水线
[EditorConfig](https://editorconfig.org/) 固定 UTF-8/LF/缩进；[Ruff formatter](https://docs.astral.sh/ruff/formatter/) 与 [Prettier](https://prettier.io/docs/options) 的标准输出不等于本规范：Python 顶层函数可能回到 2 空行，Prettier 通常把双空行压成 1；不能运行两套互相打架的强门禁。
实施工具须先做最小可用性验证，固定各语言profile及必要fixture；只治理本项目选用的语言，不为未来可能语言先写全套编译器。定制检查未实现时报告待完成，不把人工检查称为自动门禁通过，也不以压行/生成排除绕规则。
选定方案：固定版本基准 formatter → AST/tokenizer 安全的声明空行规范化 → 自定义行数/空格/空行 checker → lint/类型/测试。规范化必须只改语法外 whitespace，不动字符串、注释内部、装饰器或条件指令；两次整体输出 byte 相同才通过幂等检查。最终 check 比较**整个 pipeline**输出，不同时要求原始 formatter --check 对最终文件通过。
Swift [swift-format 配置](https://github.com/swiftlang/swift-format/blob/main/Documentation/Configuration.md) maximumBlankLines=2 只是上限，不保证类型间恰好 2；[SwiftLint](https://realm.github.io/SwiftLint/rule-directory.html) 原生 length/complexity 口径也不等于本规范，需补 custom checker。UTS/uvue formatter/parser 先验证兼容；不支持就固定 lint + 项目自定义 formatter，不假称 Prettier 已支持四端。本方案待工程阶段实现并测试，不是已存在工具。
Python 采用静态类型检查 [mypy](https://mypy.readthedocs.io/en/stable/getting_started.html) 等经项目选择工具；迁移工具如 [Alembic](https://alembic.sqlalchemy.org/en/latest/) 是选择，不是未来项目强制依赖。Swift 避免 force unwrap 与 try? 吞错误，UI main actor、异步取消、生命周期任务实际目标系统兼容；Observation/ObservableObject 依据最低版本确定，不能猜可用版本。

## 8. 共用组件与平台 adapter
共享语义 token、素材、组件行为、契约和业务规则；不同原生技术不承诺源码共用。权限/录音/文件/login/系统主题/安全存储通过平台 adapter；页面不能散落平台条件。Web 使用自己的能力实现，平台编译通过不代表运行功能可用。
| 组件 | 最小行为合同 |
| --- | --- |
| button | kind/size/loading/disabled/action，防连点，加载不丢标签与焦点 |
| dialog/sheet | open/title/content/actions、关闭/取消策略、焦点恢复、键盘、安全区、滚动 |
| toast/banner | 语义级别/消息/操作/超时，关键错误不只短 toast，读屏通知 |
| form/input | value/error/required/keyboard、label 与错误绑定、提交/验证/焦点 |
| list/pagination | items/loading/empty/error/retry，mobile 加载更多、desktop 分页语义一致 |
| card/container | padding/width/layout、点击态和非点击态，响应限宽/安全区 |
| recorder | idle/recording/interrupted/recorded/uploading/error，时长真实，不假波形 |
| feedback | pending/partial/success/error、依据/不确定、可重试，不伪造进度百分比 |
| calendar | 目标日期/完成时间/补卡/选中态，状态文字或图形而非仅颜色 |
| reward | confirmed/pending/locked、来源与版本，状态保存后播动画，不靠动画发奖 |

组件明确 props/input、events/output、状态与错误，不直接访问供应商；由业务用例注入操作。禁用仍可读，loading 和 empty 分离，hover 仅支持鼠标时使用；触控有 pressed，键盘有 focus。不同端框架保留其约定。[Vue 风格指南](https://vuejs.org/style-guide/rules-strongly-recommended.html) 是参考，不覆盖选定平台编译限制。

## 9. 主题、布局与动画通用合同
必须定义完整语义 token：page/card/elevated/input 背景；primary/secondary/tertiary text/icon；primary/secondary button fg/bg；link；highlight/selection fg/bg；focus/selection border；hover/pressed/disabled；border/divider/scrim/shadow；success/warning/error/info bg/fg/icon；领域组件 recording/progress/calendar/reward。主题颜色不得硬编码在页面；overlay、弹层、toast、图标同时消费当前主题，不能缓存旧色。
颜色值、模式、主题数量由 project profile 填写；推荐模式 system/light/dark 与配色组分离、按设备保存，不无需求跨设备同步。Swift 与 CSS/UTS 从同一 token schema 映射，样式单位按目标平台逻辑单位，不用设备物理像素直接统一。
普通正文 >=4.5:1，大字 >=3:1，必要控件边界/状态图形 >=3:1；图标/文字共用 fg 并实际核对。disabled 等不活跃状态可按标准例外，但仍尽量可读；颜色不作唯一状态信息。透明色按实际底色合成再算，文字大字须按真实字号/粗细判断，不能用装饰性阴影冒充控件边界。
[WCAG 文字对比](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum) 与 [非文字对比](https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast) 是判据；数值计算不等于 UI/读屏/设备验收。所有宣称合规的 token pair 建清单，sRGB 线性化、相对亮度与 (Lmax+0.05)/(Lmin+0.05) 可复算，图像/半透明组合另外测。
布局规定 title/section/body/helper/domain 字号、动态字号、spacing/radius/触控目标、安全区、窄屏/平板/桌面。动画只解释状态，点击/转场/奖励时长由项目固定，可跳过、低性能降级、后台停视觉计时，减少动态效果有静态替代。[Apple 布局](https://developer.apple.com/design/human-interface-guidelines/layout)、[减少动态效果](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/reduced-motion-evaluation-criteria) 提供平台参考，不强制其他端 API。

## 10. 状态、工作流与数据一致性
业务状态、后端任务状态、客户端交互状态分别建模；明确合法转移/终态/重试/取消、版本、拥有者和恢复点。事务/唯一约束保护业务幂等，客户端稳定请求 ID，不能靠 UI 防连点保证不重复执行。
异步任务持久化、租约领取、版本条件更新、心跳/超时回收、有界 retry_wait 和 attempt 数。取消后迟到回包不能复活任务；外部调用记录 provider/request/step/version/预算预留/结果状态。非幂等外部调用结果未知需 reconcile/人工处理，不能盲重试并宣称 exactly-once。
允许部分步骤先返、只重试失败步骤、成功付费结果复用；依赖步骤等前置证据，有限超时/重试与预算统一执行。工作流 checkpoint 只保存执行上下文，不替代调度器、业务 DB、权限或去重账本；单体可独立 worker，不无需求微服务。
输入校验、错误码、配置管理、日志脱敏、迁移、权限、费用/资源上限为边界职责。状态恢复、离线队列、删除 tombstone、导出报告与可恢复备份分开设计；恢复先预览冲突，再确认，不自动复活删除项。数据时间/业务日期/客户端声明时间清楚。

## 11. 验收、PR 与例外
| 层次 | 必须报告的证据 |
| --- | --- |
| 静态/格式 | pipeline 幂等、行数/复杂度、类型、注释/编码、具名例外，未实现 checker 列明 |
| 业务/持久化 | 关键规则、真实事务竞态、迁移、幂等/恢复/删除，不能全 mock DB |
| adapter/外部服务 | mock 仅编排；真实调用凭据合法授权、版本/样本/费用/错误证据脱敏 |
| UI/平台 | 每目标端编译模式/版本、设备/系统、布局/键盘/权限/中断/离线/主题/减少动态效果 |
| 发布/运维 | 另行授权、仓库规则、精确提交/构建、备份恢复/健康检查/回滚，不把计划当已发布 |

PR 写清问题、最终行为、边界、契约/迁移影响与实际验证；不绕 hooks、审计、CI 或目标分支要求。无需求不加测试镜像实现；关键业务/竞态/恢复必须测。新变更后失败/未决再扩测，不为凑证据重复已通过耗时测试。文档与实现同步，例外不能永久隐藏。
例外模板：ID；路径/规则；原因；替代保护；实际有效行/风险；责任人；批准依据；到期/移除条件；验收证据。长 URL、生成路径、Makefile tab、机器格式注释豁免均列此模板；紧急例外不能绕安全/权限或用户禁止事项。来源链接已就近附于对应规则；官方默认、项目选择与尚待实现工具必须区分。
