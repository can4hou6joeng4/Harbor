# AI 基座 + 摘要

## Goal

Replace the current simulated AI summary path with a real, explicit, local-first Anthropic integration foundation. Task F must deliver the shared AI service boundary, secure API key storage, settings entry point, and end-to-end structured summary generation persisted back into local storage.

## Requirements

- Follow `.trellis/spec/guides/ai-integration-design.md` as binding design, especially the product redlines in §0, architecture in §2, request/error handling in §4-§5, persistence in §6, settings in §8, tests in §9, task split in §10, and self-check in §12.
- Add `ReaderCore/AI/` foundation:
  - `AIService` protocol for summary, translation, chat, and remix extension points.
  - `AnthropicService` as the only service implementation aware of Anthropic requests.
  - `AIClient` transport abstraction with URLSession implementation and mockable streaming/JSON behavior.
  - `AIError` HTTP/status mapping with retry policy support.
  - `Prompts` centralized request/prompt construction.
  - `APIKeyStore` using Keychain only for the Anthropic API key.
  - `AISettings` for model selection and explicit enablement settings, excluding the API key.
- Wire a settings sheet from the sidebar gear:
  - Secure API key input saved to Keychain.
  - Masked configured state.
  - Model selection for the allowed Anthropic models.
  - Test connection action.
  - Privacy disclosure that AI processing sends selected content to Anthropic and stores generated results locally.
- Implement summary end-to-end:
  - User action triggers a structured Anthropic summary request.
  - Decode structured output into `ReaderSummary`.
  - Persist summary to existing `summary_json` via repository/save-item path.
  - Restart/reload displays the saved local summary without needing another API call.
- Remove or stop using `ReaderStore.generateReply` simulation for summary behavior.
- When AI is unconfigured, AI tabs show connect-AI guidance and no fake generated summary.
- Do not implement Task G translation behavior or Task H chat/remix streaming UI beyond protocol/base plumbing required by F.

## Acceptance Criteria

- [ ] With a real Anthropic key configured, generating a summary for an article returns a real structured summary, saves it locally, and still displays after app restart.
- [ ] With no API key configured, the AI summary area shows connect-AI guidance and does not generate or display fake AI output.
- [ ] ReaderStore and View layers do not directly call `anthropic.com`, create `URLSession` Anthropic requests, or construct Anthropic JSON.
- [ ] Requests include `anthropic-version: 2023-06-01` and `x-api-key`; requests do not include `temperature`, `top_p`, `top_k`, or `budget_tokens`.
- [ ] API key is stored only in Keychain, never UserDefaults, source constants, logs, or errors.
- [ ] Fixture tests cover SSE text delta accumulation, structured summary decode, 429 retry-after retry, 401 no retry, cancellation, body truncation, ReaderStore summary persistence with mock `AIService`, and Keychain round trip/unconfigured state.
- [ ] `swift build`, `swift test`, and `./script/build_and_run.sh --verify` pass.

## Definition of Done

- Task F code is committed with the project commit-message convention.
- Trellis journal records implementation and verification results.
- Task F is archived only after verification is green.
- Only after F passes and is archived may Task G be created and started.

## Technical Approach

Use a protocol-first AI layer under `Sources/ReaderCore/AI/`. `AnthropicService` composes `AIClient`, `APIKeyStore`, `AISettings`, and prompt builders. `ReaderStore` receives an `AIService` dependency and owns UI-facing state, persistence, and user-visible error messages. SwiftUI views remain presentation-only and call store actions.

The summary request uses structured JSON output matching `ReaderSummary`. The service truncates long article text before request construction and returns decoded local model types. Persistence reuses the existing `summary_json` column and repository `saveItem` path; no migration is planned for F.

## Decision (ADR-lite)

**Context**: The app promises local-first storage, while cloud AI sends content to Anthropic. The design guide already chooses BYO Anthropic key, direct URLSession transport, and local persistence of generated outputs.

**Decision**: Implement the exact F slice from §10: AI base, secure settings, and summary only. Keep translation/chat/remix protocol seams but leave their user-facing behavior for G/H.

**Consequences**: The architecture can grow into translation and streaming chat without moving HTTP or prompt logic into UI/store layers. The first slice remains reviewable and testable, with zero real API calls in automated tests.

## Out of Scope

- Full translation and selection translation.
- Chat streaming UI integration and remix templates.
- Local model provider implementations.
- Provider proxy server, OpenAI/multi-provider support, tools/agents/MCP.
- Persistent chat history or sync.

## Technical Notes

- Binding spec: `.trellis/spec/guides/ai-integration-design.md`.
- Related guide indexes: `.trellis/spec/guides/index.md`, `.trellis/spec/backend/index.md`, `.trellis/spec/frontend/index.md`.
- Relevant existing areas to inspect before coding: `ReaderStore`, AI assistant views, sidebar settings gear, repository summary persistence, and existing capture-layer mock/test patterns.
