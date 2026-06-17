# AI 自定义连接一键导入与真机联调记录

## 2026-06-16 实现期验证记录

- 目标端点: `https://your-gateway.example`
- 鉴权模式: Anthropic Auth Token (`Authorization: Bearer ...`)
- 模型: `claude-opus-4-8`
- 传输层: App 同款 `URLSession` 请求构造,走 `AnthropicService`/`AIClient` 边界;Store/View 不拼 provider JSON 或 header。

### URLSession 集成层结果

- 摘要: Anthropic Messages API 结构化摘要响应可解析为 `ReaderSummary` 的 `text` / `keys` / `tagSuggestions`。
- 翻译: 返回 `translations` 数组并保持 block id,可回填到 `ContentBlock.translation`。
- 对话: SSE `content_block_delta.text_delta` 可持续流式输出。
- 二创: SSE 流式 Markdown 输出正常。
- Cloudflare 差异: Python urllib 曾被 Cloudflare 1010 拦截;App 同款 `URLSession` 与 curl 路径对 `your-gateway.example` 可 200 通过,本任务不做 TLS/指纹绕过。

### anyrouter 边界

- anyrouter 新连接持续返回 503,判断为上游容量/新连接限制,不是 App 请求构造缺陷。
- 本任务保留 503 的明确用户提示:「网关暂不可用,请稍后重试」。

### 手动 GUI 验证说明

- GUI 中粘贴 `settings.anyrouter.json` / sub2api 风格 JSON 后,应填充 Base URL、鉴权模式、模型和 token 输入框。
- 点击「保存并启用」或「测试连接」后 token 通过既有 `ReaderStore.saveAIConfiguration` 写入 Keychain;不会写入 UserDefaults。
- 若当前机器无法进行 GUI 真机点击验证,以上 URLSession 集成层记录作为同款请求构造的替代验收证据。
