# 客户端上下文、统计与请求追踪

版本：1.1；日期：2026-10-11；状态：用户已要求将本方案写入项目文档，本次审阅补充缺省组合/CORS及网络边界，尚未实现。关联契约 EC-API-0.1；新增请求元数据为可选扩展，不改既有请求体、业务枚举或授权规则。

## 1. 放置位置与职责

所有 App API 请求由统一网络模块附加 HTTP headers，包括 JSON、multipart 上传、轮询、导出与登录请求。页面不得逐接口拼装。预签名第三方下载 URL 不附带 App Authorization 或自定义 headers；仅对本 App API 域名注入。
SwiftUI 与 uni-app x 各有自己的网络封装，共享本文件的字段定义。后端 middleware/dependency 集中校验并构建 RequestContext，应用服务、日志、任务模块按需读取；不要求每个业务 DTO 重复这些参数。
客户端代码属性统一 lowerCamelCase，例如 clientType、clientPlatform、appVersion、requestId；Python 内部按 snake_case 映射。HTTP header 名遵守下面的协议写法，不受变量命名规则约束，大小写不敏感。

## 2. 字段契约

| HTTP header | 内部语义 | 值与用途 |
| --- | --- | --- |
| X-Client-Type | clientType | swiftui / uniAppX；区分客户端实现系列 |
| X-Client-Platform | clientPlatform | ios / ipados / wechatMiniProgram / web / android / harmonyos；区分运行平台，原生鸿蒙不填 android |
| X-App-Version | appVersion | 可发布的应用版本，例如 1.0.0；用于版本分布和问题定位 |
| X-App-Build | appBuild | 不含秘密的发布构建编号；Web/小程序也有发布编号，不能只靠用户缓存版本推断 |
| X-OS-Version | osVersion | 可选、低精度系统版本；Web 不依赖 UA 冒充可靠系统识别，未知不填写 |
| X-Installation-Id | installationId | 可选随机安装/浏览器存储实例标识；存储重置可能变化，不是硬件身份、账号或可靠设备总数 |
| X-Client-Session-Id | clientSessionId | 可选本次使用会话随机标识；用于关联操作流程，不是认证令牌 |
| traceparent | traceContext | 可选 W3C Trace Context；接入 tracing 时由 tracing SDK 构建，不拼接个人信息 |
| X-Contract-Version | contractVersion | 已有字段，仍使用 EC-API-0.1；不支持版本按原契约报错 |
| Idempotency-Key | idempotencyKey | 已有修改命令去重键；不因引入 tracing、客户端来源而改变 |

只有clientType和clientPlatform同时提供时校验组合；部分缺省分别记unknown，不把缺项当非法。clientType 与 clientPlatform 组合允许 swiftui + ios/ipados，以及 uniAppX + wechatMiniProgram/web/android/harmonyos。未来增端须同步版本化枚举与两端适配，不按任意字符串生成统计维度。
本补充所有新 headers 在 EC-API-0.1 中可缺省；旧客户端记录 unknown，不拒绝其原本合法业务请求。新客户端网络模块应完整发送前四项。提供的非法枚举、超长或控制字符统一 400 INVALID_ARGUMENT，不回显原始危险值。
上述自定义值最长128字符，installationId/clientSessionId 使用随机 UUID；它们可缺省。traceparent 按 W3C 自身格式校验，异常追踪上下文丢弃并生成新的服务端 trace，不影响合法业务请求。

## 3. 请求、任务与重试的关联

后端为每次 API 请求生成 requestId，响应 header X-Request-Id 与既有 JSON requestId 使用相同值；错误响应同样带它。二进制或无 JSON 响应以 header 提供。requestId 是每次 HTTP 请求的标识，不是用户、安装实例或去重键。
traceId 可关联 API、持久化任务执行、LangGraph 节点和供应商调用；不以客户端提供的 trace 标识直接决定采样预算、权限或服务器 requestId。单机首版可以先保存关联字段，不强制搭建独立追踪平台。
异步任务持久化 originatingRequestId、源客户端上下文快照和必要的 trace/link；worker 重启或轮询来自另一端后，仍保留任务的创建来源。每次轮询有自己的 requestId，不覆盖任务来源。
供应商调用另记录本地调用 ID、实际返回的 externalRequestId、供应商/模型版本、组件、尝试次数、状态、耗时、已确认费用或未知费用状态；不存在的厂商字段不得伪造。可从 requestId 找到 jobId/attemptId，再定位节点与外部调用。
重试请求有新的 requestId；同一业务修改继续使用原 Idempotency-Key。跨端重放不能因来源变化重复发奖：业务摘要不包含客户端来源、追踪、版本等非业务 headers，仍按现有账号/方法/路径/key与业务请求摘要去重。

## 4. 统计口径与信任边界

来源 headers 是客户端声明，可以伪造。账号来自后端验证的令牌，会话权限和 childId 归属继续由后端核验；不依据 clientType、installationId、User-Agent 或 IP 授权或判断儿童身份。
后台可按客户端、平台、版本、构建统计请求量、错误率、处理延迟分布与供应商失败。路由按模板聚合，不按含 UUID 的完整路径生成无限维度。
活跃家长按服务端账号去重，练习儿童按已授权儿童档案统计，完成日期以服务端唯一 CheckIn 为准。请求数、安装实例数、登录人数和打卡人数分别定义；匿名流量不冒充真实用户数。
首版业务统计优先使用已有服务端事实。页面浏览、点击漏斗、客户端崩溃、离线停留时间无法由 API 日志完整推断，后续需要时另设计版本化事件契约与上报 adapter；当前不添加通用任意埋点接口。
requestId、traceId、installationId、账号/儿童 ID 等高基数字段只进入受控日志或业务关联存储，不作为 metrics label。必要统计采用聚合结果，不记录儿童录音、转写全文、Token、Cookie、秘密或下载签名 URL。
installationId 是随机软件实例 ID，默认首版可不启用；不读取 IMEI、MAC、IDFA 等硬件/广告标识，不做浏览器指纹。可选诊断采集的用途、保留时间、删除与家长设置在启用前落实，不能无限期留存。

## 5. 跨端及工程边界

SwiftUI：APIClient 注入 ClientContextProvider，依赖版本/平台/存储/会话 adapter；页面不判断 platform 并写 header。
uni-app x：RequestClient 注入同语义 provider，编译和运行平台由平台 adapter 提供；未知值不猜测。小程序合法域名与 Web HTTPS/CORS 各自验证。
Web CORS 明确允许上述自定义 headers、Authorization、Idempotency-Key 和 traceparent，向浏览器 expose X-Request-Id、Retry-After（用于已知的限额重试等待）；仅允许明确的前端 origins，预检 OPTIONS 不受登录或来源字段必填约束。不能以允许自定义 header 作为跨域安全配置已完成的证据。
后端分开 RequestContext（请求生命周期）和 persisted origin metadata（必要任务关联）；不把所有 header 无筛选持久化。厂商调用不透传客户端 headers 或家长身份，只传评测所需数据。

网络边界还需验证上传/download adapter：multipart边界由实际平台库生成，不由页面伪造Content-Type；安全重定向不能把Authorization透传到其他域名。错误路径包含网关413/429/5xx，边缘层也应提供可读requestId和必要CORS，不保证所有网关错误一定有App JSON包体；客户端支持非JSON安全降级。

## 6. 验收与兼容

覆盖六平台枚举与两实现系列、缺省旧客户端、非法组合、恶意值、登录/上传/轮询/错误响应、Web预检和 header读取。
验证 requestId 可关联后台日志/任务/厂商调用，worker重启后来源不丢失；另一端轮询不改创建来源，重试换 requestId 而保留原幂等键且只写一次奖励。
核验权限不受伪造来源影响、跨账号隔离、原音和凭据不入日志、无高基数 metrics 标签；统计按各自口径去重。
仅完成本设计补充；未执行应用代码、真实数据库、跨端、日志平台或供应商验证。未来 schema/OpenAPI 发布需同步此可选扩展；若将新字段改为必填，必须另做兼容性版本变更。

参考：[W3C Trace Context](https://www.w3.org/TR/trace-context/) 定义 traceparent；[OpenTelemetry HTTP conventions](https://opentelemetry.io/docs/specs/semconv/http/http-spans/) 定义 HTTP 可观测性标准属性。自定义 X-Client-* 是本项目选择，不是上述标准规定。
