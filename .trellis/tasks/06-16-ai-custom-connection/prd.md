# AI 自定义连接一键导入与真机联调

## Goal

让「自定义 Anthropic 兼容连接」在 GUI 里真正好用并经真机联调验证:支持粘贴/导入形如 `settings.anyrouter.json` 的连接配置一键填充设置项;Anthropic 模型改为自由文本(覆盖枚举);把网关错误(Cloudflare 拦截 / 503 / 401 / 超时)映射成可读中文;并完成摘要/翻译/对话/二创四链路的真机联调手动验证记录。本任务是 Task I(自定义端点)的 UX/健壮性收尾 + 端到端验证,不扩展新 AI 能力。

## What I Already Know

* Task I(commit `82fba2c`)已为 Anthropic provider 加:`anthropicBaseURLString`、`anthropicAuthMode`(apiKey/authToken)、`anthropicCustomModel`、`anthropicBeta`,以及 `[1m]` 后缀→剥离 + `context-1m-2025-08-07` beta 头;`messagesEndpoint` 规整 host/`/v1`/完整 endpoint;75 个测试全绿。
* 本会话真机验证(经 `https://sub2api.bobochang.cn`,真实 `claude-opus-4-8`)已确认:四链路请求/响应正确(摘要结构化 schema 完整、翻译保 id、对话 25 deltas、二创 154 deltas Markdown),且 **App 同款 URLSession 直接 200 通过该网关的 Cloudflare**(Python urllib 被 Cloudflare 1010 拦截,URLSession/curl 放行)。
* anyrouter 对新连接持续 503(外部容量/掐新连接),非 App 缺陷。
* 设置 sheet 在 `OverlaysView.swift`;连接配置在 `AISettings.swift`;请求构造/头在 `AnthropicService.swift`;错误类型在 `AIError.swift`。
* 用户常用的连接配置是这种 JSON 形状:`{"env":{"ANTHROPIC_BASE_URL":"...","ANTHROPIC_AUTH_TOKEN":"sk-..."},"model":"xxx[1m]"}`。

## Scope Decision

做:导入解析、自由文本模型、错误友好化、测试连接错误信息、真机联调记录。
不做:读取 env 代理;非 Anthropic/OpenAI 报文模板;TLS 指纹伪装(URLSession 已能过 Cloudflare,无需处理);X/微博/YouTube 抓取。

## Requirements

* 设置里新增「导入连接配置」入口:粘贴上面 JSON 形状 → 自动设置 Provider=Anthropic、Base URL、鉴权模式=Auth Token、`ANTHROPIC_AUTH_TOKEN`→Keychain、模型=`model`(`[1m]` 后缀按既有机制保留 1M)。解析失败(非法 JSON / 缺 `ANTHROPIC_BASE_URL` 或 token)给明确中文提示,不静默吞。
* Anthropic 模型支持**自由文本**输入(保留枚举作快捷选择),以适配网关自定义模型名。
* 错误友好化:`AIError` / 失败路径把以下映射成可读中文并在「测试连接」与 AI 操作失败时展示:
  * 403 / Cloudflare(响应含 `error code: 1010` 或 HTML 质询)→「网关拒绝访问(可能被 Cloudflare 拦截或客户端不被允许)」
  * 503 →「网关暂不可用,请稍后重试」;429 →「请求过于频繁,请稍后」
  * 401 →「鉴权失败,请检查 Token / Key」
  * 超时 / 连接失败 →「无法连接到端点(...)」
* 「测试连接」返回具体成功(显示命中的模型/耗时即可)或上面具体失败原因。
* 隐私文案显示真实 host(非默认端点要标注)。

## Acceptance Criteria

* [ ] 粘贴 anyrouter/sub2api 风格 JSON → 设置项被正确填充(Base URL / 鉴权=Auth Token / 模型 / Keychain 有 token);单测覆盖解析器:正常、含 `[1m]`、缺字段、非法 JSON、含多余字段。
* [ ] 自由文本模型生效:单测 任意模型串 → 请求 `model` 字段正确;`foo[1m]` → `model=foo` 且头含 `anthropic-beta: context-1m-2025-08-07`(沿用 Task I)。
* [ ] 错误映射单测:403(1010)/503/429/401/超时 → 对应中文消息。
* [ ] token 仍只在 Keychain;粘贴/导入的明文不落盘;隔离纪律不破(Store/View 不拼 provider JSON/headers)。
* [ ] `swift build` && `swift test` && `./script/build_and_run.sh --verify` 全绿。
* [ ] **真机联调记录**(写进本任务 info.md 或 journal):用 `base=https://sub2api.bobochang.cn`、鉴权=Auth Token、`model=claude-opus-4-8` 在真机 App 里跑通 摘要/翻译/对话/二创 四链路并记录结果;若环境无法启动 GUI,至少记录 URLSession 集成层(同款请求体)对该端点 200 且四链路响应结构正确。

## Definition Of Done

* 符合现有 `AIService`/`AISettings`/`AnthropicService` 结构与隔离边界,不大改架构。
* 错误映射有针对性测试;导入解析有测试;无法自动化的 GUI 行为记录手动验证方式。
* 不影响既有 Anthropic 直连默认行为(默认值下仍直连 api.anthropic.com、x-api-key)——回归通过。

## Out Of Scope

* 读取 `HTTP(S)_PROXY` 环境变量;系统代理之外的代理处理。
* TLS/JA3 指纹伪装(URLSession 已能过目标网关 Cloudflare)。
* 非 Anthropic/非 OpenAI 的任意请求模板;新增云 provider。
* X / 微博 / YouTube 抓取;本地模型实现。

## Technical Notes

* 入口文件:`Sources/ReaderCore/AI/AISettings.swift`(连接配置 + 导入解析)、`Sources/ReaderMacApp/Views/OverlaysView.swift`(设置 sheet UI:粘贴框、自由文本模型、错误展示)、`Sources/ReaderCore/AI/AnthropicService.swift` 与 `AIError.swift`(错误映射)。
* 约束参考:`.trellis/spec/guides/ai-integration-design.md` §8(设置界面)、§13(自定义 Anthropic 端点)、§5(错误与限流)。
* 真机对照(本会话已验证,可作实现期基准):
  * `curl`/URLSession + `Authorization: Bearer <token>` + `https://sub2api.bobochang.cn/v1/messages` + `model=claude-opus-4-8` → 200,真实回复。
  * 结构化摘要返回 `{text,keys,tagSuggestions}`;翻译返回 `{translations:[{id,text}]}` 保 id;对话/二创 SSE `content_block_delta.text_delta` 流式正常。
  * Cloudflare 仅按客户端指纹拦截(Python urllib 1010);URLSession 不受影响,**不需要**为此写任何绕过。
