# Anthropic 自定义端点 + 连接配置

## Goal

按 `.trellis/spec/guides/ai-integration-design.md` §13/§14,把现有 Anthropic provider 从固定官方 endpoint/key/model 改为可配置连接,支持 anyrouter/自建 Anthropic 兼容网关等真实使用场景,同时保持默认直连 Anthropic 的行为不变。

## What I Already Know

- 用户明确要求创建并实现 Task I「Anthropic 自定义端点 + 连接配置」。
- §13 是约束性增量,优先于旧 out-of-scope;它只扩展 Anthropic 协议的自定义端点,不新增 Provider,也不引入任意请求模板。
- 当前 `AnthropicService` 固定 `https://api.anthropic.com/v1/messages`,固定 `x-api-key`,固定使用 `AISettings.selectedModel`,不支持 `anthropic-beta`。
- 当前 OpenAI-compatible Custom 已有 base URL 规整思路,但 Anthropic 需要 `/v1/messages` endpoint 规则。
- 当前设置页已有 provider picker,Anthropic provider 下可扩展 Base URL、鉴权模式、自定义模型和 beta 字段。

## Assumptions

- Anthropic 自定义连接配置属于 Anthropic provider 的连接设置,Keychain service 仍使用 `.anthropic` provider 隔离,不另建 provider。
- 鉴权模式只影响请求头名称和值,不影响 Keychain 存储位置。
- `[1m]` 后缀由 service/request builder 解释:实际请求体模型要剥掉后缀,并自动添加 `context-1m-2025-08-07` beta。
- 附加 beta 字段为逗号分隔字符串;最终请求头去空白、去重,并与 `[1m]` 自动 beta 合并。

## Open Questions

- None. 规格已给出 MVP 约束和验收。

## Requirements

- Anthropic provider 设置:
  - Base URL 可选,默认 `https://api.anthropic.com`。
  - 鉴权模式枚举:API Key(`x-api-key`,默认) / Auth Token(`Authorization: Bearer`)。
  - 自定义模型字符串可选,为空时继续使用 Anthropic 模型枚举。
  - 附加 `anthropic-beta` 字段可选,逗号分隔。
  - 设置 UI 在 Anthropic provider 下展示这些字段,并提示 macOS 系统代理行为。
- Anthropic 请求:
  - endpoint 由 base URL 规整为 `/v1/messages`,支持 host、`/v1`、完整 `/v1/messages` 三种输入。
  - 默认配置时请求 endpoint/header/body 与现状兼容。
  - `authToken` 模式发送 `Authorization: Bearer <token>`,不发送 `x-api-key`。
  - `apiKey` 模式发送 `x-api-key`,不发送 `Authorization`。
  - 模型字符串以 `[1m]` 结尾时,请求体 `model` 剥掉后缀,并发送 `anthropic-beta: context-1m-2025-08-07`。
  - 附加 beta 与自动 beta 合并到同一个 `anthropic-beta` header。
  - 禁发 `temperature` / `top_p` / `top_k` / `budget_tokens`。
- Boundary:
  - Provider endpoint/header/body 细节仍只在 `ReaderCore/AI`。
  - Store/View 只传配置值,不拼 URLRequest/provider JSON/provider header。
  - Key/token 仍只存 Keychain;base URL/model/beta/auth mode 存 UserDefaults。

## Acceptance Criteria

- [ ] Anthropic provider 可配置 base URL / 鉴权模式 / 自定义模型 / beta。
- [ ] 默认值不变时,直连 `api.anthropic.com` 行为与现状一致。
- [ ] 单测覆盖 `foo[1m]` -> request body `model == "foo"` 且 header 含 `anthropic-beta: context-1m-2025-08-07`。
- [ ] 单测覆盖 `authToken` 模式发 `Authorization: Bearer`, `apiKey` 模式发 `x-api-key`。
- [ ] 单测覆盖 base URL 规整:host、`/v1`、完整 `/v1/messages`。
- [ ] mock 传输覆盖 anyrouter 风格配置(base=`https://anyrouter.top`, authToken, model=`claude-fable-5[1m]`)的 endpoint/header/model 正确。
- [ ] `swift build` && `swift test` && `./script/build_and_run.sh --verify` 全绿。

## Manual Verification

- 记录 anyrouter 配置真机结果。若上游仍 503,记录请求已正确发出但被上游阻塞,并引用 `/Users/bobochang/reader-anyrouter-accept.py` 的等效验证结论。

## Definition of Done

- PRD 已创建并 task started。
- 实现、测试、规格同步完成。
- 全量验证通过。
- 代码提交、任务归档、session journal 记录。

## Out of Scope

- 任意非 Anthropic/非 OpenAI 报文模板。
- 读取 `HTTP_PROXY` / `HTTPS_PROXY` 环境变量。
- OAuth 登录态或 Claude Code 登录复用。
- 新增 OpenAI/Anthropic 以外的内置云 provider。

## Technical Notes

- Binding guide: `.trellis/spec/guides/ai-integration-design.md` §13/§14。
- Backend contract: `.trellis/spec/backend/quality-guidelines.md`。
- Likely files:
  - `Sources/ReaderCore/AI/AISettings.swift`
  - `Sources/ReaderCore/AI/AnthropicService.swift`
  - `Sources/ReaderCore/AI/Prompts.swift`
  - `Sources/ReaderCore/ReaderStore.swift`
  - `Sources/ReaderMacApp/Views/AISettingsView.swift`
  - `Tests/ReaderCoreTests/AIServiceTests.swift`
  - `Tests/ReaderCoreTests/ReaderStoreTests.swift`
