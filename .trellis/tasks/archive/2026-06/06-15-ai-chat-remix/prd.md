# 对话 + 二创

## Goal

Implement Task H from `.trellis/spec/guides/ai-integration-design.md`: wire real Anthropic streaming chat into the AI chat tab and real streaming remix generation into the remix tab. Both capabilities must stay explicit user actions, use the existing BYO-key AI foundation, and keep chat/remix output session-local rather than persisted.

## Requirements

- Follow the binding AI integration guide, especially §0 product redlines, §2 AI boundary isolation, §3 SSE streaming, §4 chat/remix request construction, §5 error handling, §6 persistence boundaries, §7 prompt placement, §9 zero-real-network tests, §10 task split, and §12 self-check.
- Implement `AIService.chat(messages:about:)` in `AnthropicService`.
  - Stream text deltas through `AsyncThrowingStream<String, Error>`.
  - Convert current chat messages to Anthropic user/assistant turns inside the AI layer, not in `ReaderStore` or SwiftUI.
  - Include current article context in the system prompt when available.
  - Use centralized prompt/request construction in `Prompts.swift`.
  - Omit forbidden model parameters: `temperature`, `top_p`, `top_k`, `budget_tokens`.
- Implement `AIService.remix(type:items:)` in `AnthropicService`.
  - Support the four templates from the design guide: `rx-note`, `rx-thread`, `rx-weekly`, `rx-cross`.
  - Stream Markdown text deltas through `AsyncThrowingStream<String, Error>`.
  - Use selected/current article content only after explicit user action.
- Update `ReaderStore` chat/remix actions.
  - `sendMessage` consumes `AIService.chat(...)`, appends an assistant message immediately, and updates it token by token.
  - Switching article or starting a new chat/remix request cancels the previous in-flight stream.
  - Remix generation has visible loading/error state and keeps output copyable in the panel.
  - Unconfigured AI shows connect-AI guidance and no fake chat/remix text.
- Keep persistence boundaries:
  - Chat messages remain session-local and are not written to the repository.
  - Remix drafts remain session-local and are not written to the repository.
- Keep Task F/G behavior intact: summary and translation still work and persist as before.

## Acceptance Criteria

- [ ] With AI configured, chat responses stream into the chat tab token by token for the current article.
- [ ] Changing the selected article cancels an in-flight chat stream.
- [ ] With AI configured, each remix template streams a Markdown draft and exposes copyable output.
- [ ] With AI unconfigured, chat/remix UI shows connect-AI guidance and does not generate fake text.
- [ ] ReaderStore and View layers do not directly call `anthropic.com`, create Anthropic `URLRequest`s, or construct Anthropic JSON.
- [ ] Tests use mock `AIService`/`AIClient`; no real API/network calls.
- [ ] `swift build`, `swift test`, and `./script/build_and_run.sh --verify` pass.

## Definition of Done

- Task H code is committed with the project commit-message convention.
- Trellis journal records implementation and verification results.
- Task H is archived after verification is green.

## Technical Approach

Extend the existing Task F/G AI foundation. `Prompts.swift` owns chat/remix request body construction, `AnthropicService` owns Anthropic streaming calls, and `ReaderStore` owns session-local UI state plus cancellation. SwiftUI views call only store actions and render store state.

## Out of Scope

- Persistent chat history.
- Saving remix drafts as reader items or notes.
- Local model providers or alternate cloud providers.
- Tool calling, agents, MCP, or external actions.
- Additional remix templates beyond the four named in the design guide.

## Technical Notes

- Binding spec: `.trellis/spec/guides/ai-integration-design.md`.
- Task F work commit: `80d541c`.
- Task G work commit: `bf2c446`.
