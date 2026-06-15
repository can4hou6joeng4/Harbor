# 多 Provider AI 基座

## Goal

将当前 Anthropic-only AI 接入改造成多 Provider 架构,内置支持 Anthropic 与 OpenAI,并为用户自定义 OpenAI-compatible Provider 预留可用路径。目标是保持本地优先与 BYO-Key 原则不变,让用户能选择自己的模型供应商、Key、Base URL 和模型,同时继续复用摘要、翻译、对话、二创四类能力。

## What I Already Know

- 用户明确希望开启新任务,引入 OpenAI 以及多 Provider(自定义)。
- 当前 `.trellis/spec/guides/ai-integration-design.md` 原先把多 Provider 标成 Out of Scope,因此本任务需要更新设计约束,不能在旧约束下静默偏离。
- 当前 `AIService` 协议已经隔离了 Store/View 与具体模型 API,这是多 Provider 的主要扩展点。
- 当前 `ReaderStore` 默认直接构造 `AnthropicService(keyStore:settings:)`;设置 UI、模型枚举、Keychain service、隐私文案、错误文案均有 Anthropic 单 provider 假设。
- 当前 `Prompts.swift` 同时承担“通用任务 prompt”和“Anthropic 请求 JSON 构造”,多 Provider 后需要拆分或至少隔离 provider-specific request builder。
- 当前测试已经覆盖 Anthropic 请求头、禁用参数、SSE parser、结构化摘要、译文、chat/remix 流式、未配置态无假结果。

## Assumptions

- MVP 继续坚持 BYO-Key,不增加中间服务器。
- MVP 继续零真实 API 测试;OpenAI 和自定义 Provider 均用 mock transport/fixture。
- MVP 不引入第三方 SDK,继续使用 `URLSession` + 可注入 transport。
- “自定义 Provider”优先理解为 OpenAI-compatible endpoint,而不是任意 JSON 协议编辑器。

## Open Questions

- None.

## Requirements

- 新增 provider 抽象:
  - 内置 Provider: Anthropic、OpenAI、Custom。
  - Store/View 只依赖 provider-agnostic `AIService`/配置接口,不拼任何 provider JSON。
  - Anthropic 既有能力保持可用。
- OpenAI 支持:
  - 用户可配置 OpenAI API Key。
  - 用户可选择 OpenAI 模型。
  - 摘要/翻译为结构化输出或严格 JSON decode;对话/二创为流式输出。
  - 错误映射与用户反馈对齐现有 `AIError` 行为。
- 自定义 Provider 支持:
  - 用户可配置名称、Base URL、API Key、模型。
  - MVP 推荐仅支持 OpenAI-compatible `/v1/chat/completions` 或等价流式协议。
  - Key 进入 Keychain,Base URL/模型/启用状态进入 UserDefaults。
- 设置 UI:
  - Provider 选择控件。
  - 按当前 provider 展示 Key、Base URL、模型输入/选择、测试连接。
  - 隐私说明必须显示实际 provider 名称或自定义 endpoint,避免误导数据流向。
- 本地优先与安全:
  - AI 默认关闭、显式启用。
  - 不自动发送内容。
  - Key 只存 Keychain,不得写入 UserDefaults、日志或错误文本。
  - Chat/remix 不持久化;summary/translation 继续按现有规则本地落库。

## Acceptance Criteria

- [ ] 用户可以在设置中选择 Anthropic、OpenAI 或 Custom provider。
- [ ] Anthropic 既有摘要/翻译/对话/二创测试继续通过。
- [ ] OpenAI provider 可通过 mock transport 完成摘要、翻译、对话、二创四类能力。
- [ ] Custom provider 使用 OpenAI-compatible mock endpoint 完成至少连接测试、摘要、流式对话。
- [ ] 不同 provider 的 API Key 分别存储,切换 provider 不会覆盖其他 provider 的 key。
- [ ] 未配置当前 provider 时,AI tab 显示连接引导,不展示伪造结果。
- [ ] ReaderStore/View 层不出现 `anthropic.com`、`api.openai.com`、provider-specific headers 或 provider-specific JSON。
- [ ] `swift build`, `swift test`, `./script/build_and_run.sh --verify` 全绿。

## Definition of Done

- PRD 经过用户确认。
- 相关 `.trellis/spec/` 设计约束更新,明确多 Provider 合同。
- 实现代码提交,任务归档,session journal 记录验证结果。

## Expansion Sweep

### Future Evolution

- 未来可能加入 Ollama/Apple Foundation Models,因此 provider 抽象不应把所有 provider 都假设成云端 API。
- 未来可能有 per-task model 选择,但 MVP 先做全局当前 provider + 当前模型。

### Related Scenarios

- 设置页、AI tab 未配置态、错误提示和隐私文案必须随 provider 一致变化。
- 现有 summary/translation 落库行为不能因 provider 切换改变。

### Failure & Edge Cases

- OpenAI-compatible 自定义 endpoint 可能不支持结构化输出或流式格式,需要明确错误提示。
- Base URL 校验必须避免空值、非 HTTP(S)、尾随路径拼接错误。
- 不同 provider 的 key/service 名必须隔离,避免 Anthropic key 被误发到 OpenAI/custom endpoint。

## Feasible Approaches

### Approach A: Provider 抽象 + OpenAI-compatible Custom(推荐)

- How: 保留 `AIService` 上层协议,新增 provider 配置与 service factory;Anthropic 与 OpenAI 各自实现 provider-specific request/response builder;Custom 复用 OpenAI-compatible 实现,只替换 Base URL、模型、名称。
- Pros: 覆盖用户诉求,实现范围可控,不会让 UI 暴露任意 JSON 高复杂度。
- Cons: 自定义 Provider 必须兼容 OpenAI API,不支持任意私有协议。

### Approach B: 仅做 OpenAI Provider,Custom 延后

- How: 先把 Anthropic/OpenAI 双 provider 跑通,自定义作为下一任务。
- Pros: 风险最低,测试面较小。
- Cons: 不满足用户本次“多provider(自定义)”的完整诉求。

### Approach C: 任意自定义 Provider 请求模板

- How: UI 允许用户编辑 endpoint、headers、JSON body template、响应路径。
- Pros: 极强灵活性。
- Cons: UX 和安全边界复杂,测试困难,很容易破坏本地优先透明披露;不适合作为本阶段 MVP。

## Recommended MVP

采用 Approach A:

- Anthropic 内置 provider 保持现有能力。
- OpenAI 内置 provider 使用官方 OpenAI endpoint。
- Custom provider 只支持 OpenAI-compatible endpoint。用户已确认此范围。
- 不做任意请求模板、不做本地模型、不做 per-feature model routing。

## Decision (ADR-lite)

**Context**: 当前实现是 Anthropic-only,但产品需要支持用户已有 OpenAI Key,并为自定义 Provider 留出可用路径。任意自定义请求模板会显著增加 UI、安全披露、测试和错误处理复杂度。

**Decision**: 本任务采用 Provider 抽象 + OpenAI-compatible Custom。内置 Anthropic 与 OpenAI;Custom 只配置名称、Base URL、API Key、模型,并复用 OpenAI-compatible 请求/响应协议。

**Consequences**: MVP 覆盖主流 BYO-Key 和多数代理/兼容服务场景,同时保持可测性和隐私披露清晰。非 OpenAI-compatible 的私有协议留到后续任务。

## Out of Scope

- OpenAI 以外的内置云 provider。
- Ollama / Apple Foundation Models 本地 provider。
- 任意 JSON/template provider 编辑器。
- 多账号 profile、per-task model routing、用量统计、成本估算。
- 将 chat/remix 持久化。

## Technical Notes

- Binding guide to update: `.trellis/spec/guides/ai-integration-design.md`.
- Current AI code:
  - `Sources/ReaderCore/AI/AIService.swift`
  - `Sources/ReaderCore/AI/AISettings.swift`
  - `Sources/ReaderCore/AI/APIKeyStore.swift`
  - `Sources/ReaderCore/AI/AnthropicService.swift`
  - `Sources/ReaderCore/AI/Prompts.swift`
  - `Sources/ReaderMacApp/Views/AISettingsView.swift`
  - `Sources/ReaderCore/ReaderStore.swift`
- Current backend AI contract: `.trellis/spec/backend/quality-guidelines.md`.
