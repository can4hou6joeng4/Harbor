# AI 服务接入设计指南(AI Integration Design Guide)

> **读者**:接下来把模拟 AI 换成真实调用的 AI 开发者(Codex)。
> **地位**:与 `persistence-design.md`、`content-capture-design.md` 同级的**约束性设计决定**。冲突先在 task `info.md` 记录,不要静默偏离。
> **背景**:四个 AI 能力(摘要/翻译/对话/二创)已通过 `AIService` 接真实模型。本层当前支持 Anthropic、OpenAI 与 OpenAI-compatible Custom Provider。**Provider API 细节以本文为准,不要凭记忆改。**

---

## 0. 一条贯穿始终的产品红线:本地优先 vs 把内容发出去

本应用的核心承诺是「数据都在本地」。调用云端模型**必然**把文章正文/选区发到用户选择的 Provider 或自定义 endpoint——这与承诺存在张力。因此 AI 是**增强项,不是默认行为**,必须满足:

1. **默认关闭、显式开启**:未配置 API Key 时,AI 各 tab 显示「连接 AI」引导,**不展示任何伪造摘要**(种子示例数据除外)。
2. **首次开启时明确告知**:一句话披露「使用 AI 会把所选内容发送到当前 Provider 或自定义 endpoint 进行处理」,用户确认后才启用。
3. **绝不自动发送**:摘要/翻译只在用户点击时触发,不在抓取/打开文章时静默调用。
4. **结果回流为本地数据**:AI 生成的摘要/译文**落库**(见 §6),之后离线可读——这反而强化了「本地优先」:云端只是一次性加工,产物归你、留在本地。
5. **BYO-Key**:用户自带自己的 Anthropic/OpenAI/自定义 Provider API Key,直连所选 Provider,**我们不设中间服务器**,不经手任何内容。这是最契合本产品的形态。
6. **为本地模型留接口**:`AIService` 协议下,未来可加 Apple Foundation Models / Ollama 的本地实现,做到真正不出设备。本期不实现,但协议必须容得下。

---

## 1. 技术选型(已定)

| 项 | 选型 | 理由 |
|---|---|---|
| Provider | **Anthropic Messages API**、**OpenAI Chat Completions API**、**OpenAI-compatible Custom Provider** | Anthropic 保留既有质量路径;OpenAI 覆盖用户常用 BYO-Key;Custom 仅支持 OpenAI-compatible 协议,不做任意模板 |
| 传输 | **原生 `URLSession`(无第三方 SDK)** | 直连可控、可测、零依赖。流式用 `URLSession.bytes(for:)` 逐行读 SSE |
| 默认模型 | Anthropic: **`claude-opus-4-8`**; OpenAI: **`gpt-4.1-mini`** | 设置里按 Provider 切换模型;Custom 由用户填写 OpenAI-compatible 模型名 |
| Key 存储 | **Keychain(Security 框架)** | 唯一可接受方式;禁止 UserDefaults/明文/代码内硬编码 |

**Anthropic 固定头**:`content-type: application/json`、`anthropic-version: 2023-06-01`;鉴权按连接配置发送 `x-api-key: <用户的 key>` 或 `authorization: Bearer <用户的 token>`;有 beta 配置时追加 `anthropic-beta`。**OpenAI-compatible 固定头**:`content-type: application/json`、`authorization: Bearer <用户的 key>`。

**模型参数红线(opus-4-8 / fable-5 上发了会 400)**:**不要发** `temperature` / `top_p` / `top_k` / `budget_tokens`。用 prompting 控制行为。思考链:摘要/翻译**省略 `thinking` 字段**(更快);对话/二创可选 `thinking: {"type":"adaptive"}`。可选 `output_config: {"effort": "low|medium|high"}` 调深浅(摘要/翻译用 `low`,对话用 `medium`)。

---

## 2. 架构

```
ReaderCore/AI/
  AIService.swift          // 协议:summarize / translate / chat / remix(全 async,流式返回 AsyncStream)
  AnthropicService.swift   // Anthropic Messages API 实现
  OpenAICompatibleService.swift // OpenAI / Custom(OpenAI-compatible)实现
  AIClient.swift           // 流式 HTTP 传输协议 + URLSession 实现(可注入 mock),含 provider SSE parser
  AIError.swift            // 错误类型(映射 HTTP 状态码)
  Prompts.swift            // 各任务的 system prompt 与请求体构造
  APIKeyStore.swift        // Keychain 读写,按 provider 隔离 key
  AISettings.swift         // provider/model/baseURL/开关(走 UserDefaults,key 除外)
  AIServiceFactory.swift   // 根据当前 provider 创建 service
```

**隔离纪律(延续前两层)**:
- 只有 `ReaderCore/AI` 知道 Provider HTTP/SSE 细节。`ReaderStore`、View 层依赖 `AIService`/provider 配置接口,**不出现 `URLSession` 调 provider endpoint、不拼 provider JSON、不设置 provider headers**。
- `AIService` 不依赖 GRDB,只依赖现有模型类型(`ReaderItem`/`ContentBlock`/`ReaderSummary`/`ChatMessage`)。
- `ReaderStore` 注入 `AIService`(测试注 mock);生产默认经 `DefaultAIServiceFactory` 按当前 provider 创建。

协议形态(签名可微调,职责不可少):

```swift
public protocol AIService: Sendable {
    var isConfigured: Bool { get }                                   // 是否已配置可用的 key
    func summarize(_ item: ReaderItem) async throws -> ReaderSummary // 结构化输出
    func translate(_ item: ReaderItem, to lang: String) async throws -> [String: String] // blockID→译文
    func chat(messages: [ChatMessage], about item: ReaderItem?) -> AsyncThrowingStream<String, Error> // 流式 token
    func remix(type: String, items: [ReaderItem]) -> AsyncThrowingStream<String, Error>               // 流式 token
}
```

`ReaderStore.generateReply` 整个删除;`sendMessage` 改为消费 `chat(...)` 的流(逐 token 追加到当前 `ChatMessage.text`,UI 实时刷新)。

---

## 3. 流式(SSE)处理

请求体加 `"stream": true`。响应是 Server-Sent Events,逐行解析:

- 关心的事件:`content_block_delta`(`delta.type == "text_delta"` → 取 `delta.text` 累加)、`message_delta`(读 `stop_reason` 与 `usage`)、`message_stop`(结束)。
- `content_block_start` / `message_start` / `content_block_stop` / `ping` 忽略即可。

Swift 读法(示意,非最终代码):

```swift
let (bytes, response) = try await session.bytes(for: request)
try Self.checkStatus(response)                 // 先校验 HTTP 状态(见 §5)
for try await line in bytes.lines {
    guard line.hasPrefix("data: ") else { continue }
    let json = line.dropFirst(6)
    if json == "[DONE]" { break }
    // 解析事件;text_delta → continuation.yield(text)
}
```

- 用 `AsyncThrowingStream<String, Error>` 把 token 吐给 `ReaderStore`。
- **可取消**:切换文章/关闭面板要 `cancel()` 在途请求(`Task` 持有,`onChange(of: item.id)` 取消);`URLSession.bytes` 的 task 取消即断流。
- 主线程不碰网络:服务跑在后台,token 经 `@MainActor` 回灌 store。

> 对话与二创**必须流式**(长输出 + 即时反馈)。摘要走结构化输出(下),可流式也可一次性;翻译按段返回。

---

## 4. 各能力的请求构造

统一:`max_tokens` 按任务设(摘要 1024 / 翻译 2048 / 对话 4096 / 二创 4096);正文注入前**按 token 预算截断**(粗算 1 token≈3.5 字符,超 ~150k 字符截断并在 prompt 注明「正文已截断」),避免超长请求。

**① 摘要 → 结构化输出**(保证回填 `ReaderSummary` 干净):
Anthropic 用 `output_config: {"format": {"type":"json_schema","schema": …}}`;OpenAI-compatible 用 `response_format: {"type":"json_schema", ...}`。schema 对应 `{ text:[string], keys:[string], tagSuggestions:[string] }`(`additionalProperties:false`,字段 required)。system prompt 用中文要求:摘要与要点用中文输出(界面是中文),标签 2–4 个。直接 `JSONDecoder` 成 `ReaderSummary`。
> 结构化输出与流式兼容;首个新 schema 有一次性编译延迟,之后 24h 缓存。

**② 翻译**:按 `ContentBlock` 分段译,目标语言 = 文章主语言的另一种(`item.language == "en"` → 译中,否则译英)。可让模型对每个非图片块返回译文,回填到 `ContentBlock.translation`。选区翻译(`translateSelection`)走同一服务,弹出译文。

**③ 对话**:把 `chatMessages` 转成当前 provider 的 messages 数组(role user/assistant 交替),system 里放入「你在协助阅读这篇文章」+正文(见 §7 缓存)。流式回灌。

**④ 二创**:按 `type`(rx-note/rx-thread/rx-weekly/rx-cross)选 system prompt,正文来自所选 `items`,流式输出 Markdown 草稿。

---

## 5. 错误与限流(必须健壮)

`AIError` 映射 HTTP:

| 状态 | 含义 | 处理 |
|---|---|---|
| 400 | 请求非法 | 不重试;打日志(**绝不打 key**),toast 通用错误 |
| 401 | key 无效 | 不重试;清提示「API Key 无效,请在设置中重新填写」,引导去设置 |
| 403 | 无权限 | 不重试;提示 |
| 413 | 请求过大 | 不重试;说明正文过长(本应已截断) |
| 429 | 限流 | **重试**:读 `retry-after` 头(秒)等待;无则指数退避 |
| 500 | 服务端错误 | **重试**:指数退避 |
| 529 | 过载 | **重试**:指数退避(可建议用户换更轻模型) |

- 重试上限 3 次,带 jitter;流式中途断连也走同一重试策略(整轮重发,不做增量续传)。
- **所有失败路径都要有用户可见反馈**(toast 或面板内错误态),不许静默吞掉。
- key 绝不进日志/错误信息/分析上报。

---

## 6. 结果落库(本地优先的兑现)+ Prompt 缓存

**落库(本地数据)**:
- 摘要 → 写回 `item.summary`(已有 `summary_json` 列,`repository.saveItem`)。生成过就离线可读,不必重复调。
- 译文 → 写回各 `ContentBlock.translation`(在 `body_json` 内),双语对照离线可用。
- **对话 chat 不持久化**(会话级,符合持久化指南既有约定)。
- **无需新迁移**:复用现有列即可。可选加一个 `item.summary` 是否 AI 生成的轻量标记,但非必须——本期不加迁移。

**Prompt 缓存(省钱/提速,针对同一篇文章的多次调用)**:
- 在 system 的正文块上加 `cache_control: {"type":"ephemeral"}`,这样「先摘要、再翻译、再对话」复用同一前缀缓存。
- 注意最小可缓存前缀:**Opus 4.8 = 4096 tokens**,Fable 5 / Sonnet 4.6 = 2048——短文章不会命中,属正常,不要为此加复杂度。
- 用 `usage.cache_read_input_tokens` 验证命中(调试期打点即可)。

---

## 7. Prompt 设计要点

- 每个任务一个 system prompt,集中放 `Prompts.swift`,**不要散落在 View 里**。
- 正文注入 system(便于缓存),用户指令放 user turn。
- 语言感知:摘要/要点用**中文**输出(UI 中文);翻译目标语言按 §4。
- system 里给清楚的「只输出结果、不加寒暄前言」之类约束(opus-4-8 指令遵循好,简短直接即可,不要堆 "CRITICAL/MUST")。

---

## 8. 设置界面(接线 gear 按钮)

侧栏齿轮打开设置 sheet:
- **Provider 选择**:Anthropic、OpenAI、Custom。
- **API Key 输入**(SecureField,按 provider 存 Keychain;显示当前 provider「已配置 ••••后四位」)。
- **模型选择**:Anthropic/OpenAI 用菜单;Custom 填 OpenAI-compatible 模型名。
- **Custom Base URL**:只支持 OpenAI-compatible `/v1/chat/completions` 语义;Base URL 可填 host、`/v1` 或完整 `chat/completions` endpoint。
- **「测试连接」**按钮:发一个极小请求验证当前 provider/key 有效。
- **隐私说明**:必须显示实际 provider 名称或自定义 endpoint,例如「AI 处理会将所选内容发送至 OpenAI / 自定义 Provider(...);数据仍只保存在本地」。
- 未配置 key 时,AI 各 tab 显示引导按钮跳到此设置。

---

## 9. 测试(红线:零真实 API 调用)

- mock `AIClient`(传输层)返回**预置 SSE 字节流 fixture** 与各错误状态;测试覆盖:Anthropic/OpenAI-compatible SSE 解析(多 delta 累加、跨行)、结构化摘要解码、429 读 `retry-after` 重试、401 不重试、取消断流、正文截断。
- mock `AIService` 注入 `ReaderStore`,测 `sendMessage` 流式追加、摘要落库、译文回填。
- **grep 测试代码不得出现真实 `URLSession` 发网请求**。
- key 相关:测 Keychain 读写往返、provider key 隔离 + 未配置时 `isConfigured == false`。

---

## 10. 任务拆分(三个 Trellis task,顺序执行)

**Task F「AI 基座 + 摘要」**:`AIService`/`AnthropicService`/`AIClient`(含 SSE 解析)+ `AIError` + `APIKeyStore`(Keychain)+ 设置 sheet + **摘要端到端**(结构化输出→落库)+ 删除 `generateReply` 模拟并改造未配置态。验收:填入真实 key→对一篇文章生成真实摘要→重开仍在(已落库);未配置 key 显示引导不显示假数据;`swift build`/`swift test`/`--verify` 全绿;fixture 测试覆盖 SSE 与错误码。

**Task G「翻译」**:全文翻译 + 选区翻译,译文回填 `ContentBlock.translation` 并落库,双语对照消费真实译文。验收:英文文章一键译中,逐段对照;重开译文还在;mock 传输测试。

**Task H「对话 + 二创」**:`chat` 流式接 ChatTab(逐 token 显示、可取消、引用当前文章);`remix` 四模板流式。验收:对话实时流式、切文章取消在途请求;二创生成可复制;mock SSE 流测试。

每个 task 各自 `task.py create`,PRD 引用本文档,不复述。

---

## 11. 明确不做(Out of Scope)

- 自建中间服务器代理 key(BYO-Key 直连即可)
- 本地模型实现(Apple Foundation Models / Ollama)——只留协议位
- 工具调用 / Agent / MCP(阅读器用单轮+流式足够)
- 对话历史持久化、跨设备同步
- 非 OpenAI-compatible 的任意自定义 Provider 请求模板
- OpenAI/Anthropic 以外的内置云 provider
- prompt 缓存以外的成本优化(batch 等)

---

## 12. 自查清单(提交前)

- [ ] ReaderStore/View 层无直连 provider endpoint、无 provider JSON/header 拼装
- [ ] 请求**未发** `temperature`/`top_p`/`top_k`/`budget_tokens`(否则 opus-4-8 返回 400)
- [ ] Anthropic 头部含 `anthropic-version: 2023-06-01`;鉴权按配置走 `x-api-key` 或 `authorization: Bearer`;OpenAI-compatible key 走 `authorization: Bearer`
- [ ] API Key 只在 Keychain 且按 provider 隔离;日志/错误/上报中搜不到 key
- [ ] 未配置当前 provider key:AI tab 显示引导,**不展示伪造摘要**;首次开启有实际 provider/endpoint 隐私告知
- [ ] 429 读 `retry-after` 重试;401 不重试并引导;所有失败有用户可见反馈
- [ ] 摘要落 `summary_json`、译文落 `body_json`;杀进程重开仍在
- [ ] 对话流式可取消;切文章取消在途请求;主线程无网络
- [ ] 测试零真实网络(mock 传输 + fixture SSE)
- [ ] `swift build` && `swift test` && `./script/build_and_run.sh --verify` 全绿

---

## 13. 自定义 Anthropic 兼容端点(base URL + 鉴权 + 模型 + beta)— 新增约束

> 本节为后补的**约束性增量**,优先级高于 §11 中「非 OpenAI-compatible 的自定义模板」那条 out-of-scope:本节专门补 **Anthropic 协议**的自定义端点(如 anyrouter、自建 Claude 网关、Bedrock 风格反代),与既有 OpenAI-compatible Custom 互不冲突。

**动机(实测得出)**:`AnthropicService` 端点写死 `api.anthropic.com`、只发 `x-api-key`、模型限枚举、从不发 `anthropic-beta`。导致用户实际在用的两种连接方式(直连 + 本地代理、或经 anyrouter)在 App 里**一种都用不了**。anyrouter 真机诊断已确认:它走 **Anthropic 报文**,`x-api-key` 与 `Authorization: Bearer` 都接受,且**强制要求** `anthropic-beta: context-1m-2025-08-07`(否则 400「请启用 1m 上下文」);`opus[1m]` 这种带后缀的串是 Claude Code 路由约定,**裸 API 会 404**。

**要做(把 Anthropic provider 的连接做成可配置,而非新增 provider)**:

1. **Base URL(可选,默认 `https://api.anthropic.com`)**:endpoint = baseURL 规整后 + `/v1/messages`;规整逻辑复用 OpenAI 那套(允许填 host、`/v1`、或完整 `/v1/messages`)。`https://anyrouter.top` → `https://anyrouter.top/v1/messages`。
2. **鉴权模式(枚举)**:`apiKey`(`x-api-key`,默认)/ `authToken`(`Authorization: Bearer`)。对应 Claude Code 的 `ANTHROPIC_API_KEY` vs `ANTHROPIC_AUTH_TOKEN`。Key 仍只存 Keychain。
3. **自定义模型串(可选,覆盖枚举)**:文本输入,支持任意 id(`claude-fable-5` 等)。枚举保留作快捷选择。
4. **`[1m]` 后缀 ⇄ 1M beta 头(关键,贴合用户习惯)**:模型串若以 `[1m]` 结尾,则**剥掉后缀**作为 `model` 字段,并自动追加 `anthropic-beta: context-1m-2025-08-07`。即在 App 内复刻 Claude Code 的 `opus[1m]` 写法。另提供一个通用「附加 anthropic-beta(逗号分隔)」可选字段给高级用户。
5. **请求头**:始终 `anthropic-version: 2023-06-01`;有 beta 时加 `anthropic-beta`;鉴权按模式。`temperature/top_p/budget_tokens` 仍**禁发**。
6. **隔离不变**:只有 `AnthropicService`/`AIClient` 读这些配置;Store/View 不碰。

**设置 UI 增量(在 Anthropic provider 下)**:Base URL(占位 `https://api.anthropic.com`)、鉴权模式开关(API Key / Auth Token)、自定义模型(可选)、`[1m]` 开关或附加 beta 字段。隐私文案显示真实 host(非默认端点要标注)。base URL 非 https 要警告(localhost 例外,为将来本地模型留口)。

**代理注意(写进 task 的已知项,非强制实现)**:`URLSession` 默认走 **macOS 系统代理**,不读 `HTTP(S)_PROXY` 环境变量。用户若仅靠本地 Clash(`127.0.0.1:7897`)直连 api.anthropic.com,App 需用户开启系统代理;经 anyrouter 则无需代理。本期不实现「读 env 代理」,但在设置里点明这一行为。

**Out of Scope(本节)**:任意非 Anthropic/非 OpenAI 报文模板;读取 env 代理;OAuth 登录态(只做 key/token 直填)。

---

## 14. 任务:Task I「Anthropic 自定义端点 + 连接配置」

按本指南 §13 实现。验收:
- [ ] Anthropic provider 可配置 base URL / 鉴权模式 / 自定义模型 / `[1m]`→beta;默认值不变时**直连 api.anthropic.com 行为与现状一致**(回归)。
- [ ] 单测:模型串 `foo[1m]` → 请求体 `model == "foo"` 且头含 `anthropic-beta: context-1m-2025-08-07`;`authToken` 模式发 `Authorization: Bearer`、`apiKey` 模式发 `x-api-key`;base URL 规整(host / `/v1` / 完整 endpoint 三种输入)。
- [ ] mock 传输验证:用 anyrouter 风格配置(base=`https://anyrouter.top`、authToken、模型 `claude-fable-5[1m]`)构造的请求,header/endpoint/model 三者正确(**不打真实网络**)。
- [ ] key/token 仍只在 Keychain;base URL/模型/beta/鉴权模式走 UserDefaults;隔离纪律不破。
- [ ] `swift build` && `swift test` && `./script/build_and_run.sh --verify` 全绿。
- [ ] 手动验证记录:填入 anyrouter 配置后能连通并跑通四链路(**依赖 anyrouter 配额恢复**;若仍 503 则记录「请求已正确发出、被上游 503 阻塞」并附 `/Users/bobochang/reader-anyrouter-accept.py` 的等效验证结论)。

> 真机脚本 `~/reader-anyrouter-accept.py` 已验证:`x-api-key + context-1m beta` 是 anyrouter 接受的正确组合,可作为实现期对照。
