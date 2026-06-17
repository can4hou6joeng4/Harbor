# 修复流式 SSE 解析无空行分隔兼容(对话/二创)

## Goal

修复 `AnthropicSSEParser` / `OpenAICompatibleSSEParser`:在真实 `URLSession.AsyncBytes.lines` **不产出 SSE 空行分隔**时,解析器永不 flush、把多个事件 JSON 攒到 `finish()` 一次性 `\n` 拼接解码,导致 `DecodingError.dataCorrupted`(「The data couldn't be read because it isn't in the correct format.」),使对话/二创整流失败。修复后对话/二创在 sub2api、api.anthropic.com 等真实端点恢复流式。本任务只修流式解析与其测试,不动其它 AI 能力(摘要/翻译非流式,已正常)。

## What I Already Know(根因,已实测坐实)

* 真机集成验证(经 App 自身 `AnthropicService`/`AIClient` 打 `https://your-gateway.example`,真实 `claude-opus-4-8`,鉴权 Auth Token):**摘要 ✓、翻译 ✓**;**对话 ✗、二创 ✗**,错误均为 `transport("The data couldn't be read because it isn't in the correct format.")`,且重试 3 次仍失败。
* 用 App 同款 `URLSession.bytes(for:)` 抓取 sub2api 的 200 流式响应:**总行=94,空行=0,data 条=47,单条全部合法 JSON**。即 `URLSession.AsyncBytes.lines` 对该流**不吐空行**(事件以 `event:`/`data:` 成对出现,行间无空行)。
* 把 47 条 data 负载用 `\n` 拼接后 → **不是合法 JSON**(复现 `dataCorrupted`)。
* 现状 `AIClient.swift` 中 `AnthropicSSEParser.flush()` **仅在空行(`consume` 收到空行)或 `finish()` 时触发**;无空行 → 全程不 flush → `finish()` 拼接所有 data 一次性 `JSONDecoder().decode(AnthropicStreamPayload.self)` → 抛 `DecodingError` → `AnthropicService` 的通用 catch 兜成 `.transport(error.localizedDescription)`。
* `OpenAICompatibleSSEParser` 同样依赖空行 flush,存在**同源缺陷**。
* **单测当前全绿是假象**:fixture 里手写了空行,所以测试里 flush 正常;真实 `bytes.lines` 不吐空行 → 测试与现实脱节。这正是要补的测试缺口。
* 入口:`Sources/ReaderCore/AI/AIClient.swift`(两个 `*SSEParser` 的 `consume`/`flush`);测试 `Tests/ReaderCoreTests/AIServiceTests.swift`。

## Scope Decision

做:两个 SSE 解析器的事件边界改造 + 健壮性兜底 + 补"无空行"真实流形态测试。
不做:改传输层 `URLSession.bytes` 用法、改非流式路径、改其它 provider 行为、真机 GUI 截图。

## Requirements

* 事件边界不再**只**依赖空行。解析器应在以下任一情况 flush 上一个已收集的事件:① 遇到空行;② 遇到**新的 `event:` 行**且当前已有未 flush 的 data;③ 流结束(`finish()`)。这样兼容"有空行"和"无空行"两种真实框架。
  * 注:SSE 单事件可有多行 `data:`(需用 `\n` 合并),所以**不能**简单地每条 `data:` 立即 flush;以"新 `event:` / 空行 / 结束"为边界即可同时满足多行 data 与无空行两种情况。
* Anthropic 与 OpenAI 两个解析器都修(同源问题一起解决)。
* **健壮性兜底**:单条事件负载**解码失败时跳过该事件、不中断整流**(可计数用于调试),不再把单事件解码错误冒泡成整流失败;真正的流级错误事件(Anthropic `type=="error"` / OpenAI error payload)仍按既有逻辑抛出。
* `[DONE]` 处理、`text_delta` 提取、未知/非文本事件忽略等既有语义不变。

## Acceptance Criteria

* [ ] 新单测(Anthropic):**无空行**的真实流形态(`event:`+`data:` 交替、行间无空行,覆盖 `message_start`/`content_block_start`/`ping`/多条 `content_block_delta`/`message_delta`/`message_stop`/`data: [DONE]`)→ 解析器按序产出正确的 text_delta 序列。
* [ ] 新单测(OpenAI-compatible):同样的"无空行"形态 → 正确产出 delta.content 序列。
* [ ] 保留并通过原"有空行"fixture(两种框架都必须支持)。
* [ ] 新单测:流中混入一条**无法解码**的 data 负载 → 被跳过,其余 text 仍正确产出,流不中断。
* [ ] 新单测:Anthropic `type=="error"` / OpenAI error 仍按错误抛出(回归)。
* [ ] `swift build` && `swift test` && `./script/build_and_run.sh --verify` 全绿。
* [ ] 隔离纪律不破;不引入对具体 endpoint 的真实网络测试。
* [ ] 手动验证记录(写入本任务 info.md):说明根因复现数据(sub2api 流 94 行/0 空行/47 data、拼接非法)与修复后预期;若可联网,记录对话/二创对 sub2api 流式成功;否则以"无空行 fixture"单测作为根因覆盖证据。

## Definition Of Done

* 修复后对话/二创不再因无空行流而 `dataCorrupted`。
* 测试新增"无空行"真实流形态用例,堵住测试与现实脱节的缺口。
* 不影响摘要/翻译与既有"有空行"解析行为。

## Out Of Scope

* 传输层重写、HTTP/2、TLS 指纹相关。
* 真机 GUI 点击截图(屏幕录制权限受限)。
* 其它 provider 新功能;anyrouter 容量问题(外部)。

## Technical Notes

* 关键文件:`Sources/ReaderCore/AI/AIClient.swift` —— `AnthropicSSEParser.consume/flush`、`OpenAICompatibleSSEParser.consume/flush`;私有结构 `AnthropicStreamPayload` 等保持不变。
* 复现要点:真实流 `event: X\ndata: {...}\nevent: Y\ndata: {...}\n...`(无空行),`URLSession.AsyncBytes.lines` 逐行吐出且**不含空行**;现解析器把所有 data 攒到 finish 拼接解码 → 失败。
* 错误现象串:`transport("The data couldn't be read because it isn't in the correct format.")`(`DecodingError` 的通用 localizedDescription,经 `AnthropicService` 通用 catch 包装)。
* 验证基准:摘要/翻译(非流式)对 sub2api 已确认正常,不要回归它们。
