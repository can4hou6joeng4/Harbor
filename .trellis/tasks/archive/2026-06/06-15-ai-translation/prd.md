# 翻译

## Goal

Implement Task G from `.trellis/spec/guides/ai-integration-design.md`: real AI-powered full-article translation and selection translation on top of the Task F AI foundation. Translation results must be local-first: generated text is written back into `ContentBlock.translation` and persisted through the existing `body_json` storage path.

## Requirements

- Follow the binding AI integration guide, especially §0 product redlines, §2 AI boundary isolation, §4 translation request construction, §5 error handling, §6 persistence, §7 prompt placement, §9 zero-real-network tests, §10 task split, and §12 self-check.
- Implement `AIService.translate(_ item:to:)` in `AnthropicService`.
  - Translate non-image `ContentBlock` values.
  - Return a `[String: String]` map keyed by `ContentBlock.id.uuidString`.
  - Use centralized prompt/request construction in `Prompts.swift`.
  - Omit forbidden model parameters: `temperature`, `top_p`, `top_k`, `budget_tokens`.
- Add ReaderStore translation actions:
  - Full-article translation triggered only by explicit user action.
  - Selection translation triggered only by explicit selection action.
  - User-visible loading/error states.
  - Unconfigured AI shows connect-AI guidance and no fake translation.
- Persist full translation results:
  - Write translations into each matching `ContentBlock.translation`.
  - Persist the updated `ReaderItem` via `ReaderRepository.saveItem`, reusing existing `body_json`.
  - Reload/restart should still show translated blocks.
- Update the AI translate tab:
  - Consume persisted block translations for bilingual preview.
  - Provide a clear translate button.
  - Show selected-text translation result without pretending it has been persisted unless it maps to a block.
- Keep Task H out of scope: do not implement chat streaming or remix.

## Acceptance Criteria

- [ ] With AI configured, an English article can be translated to Chinese and shown as paragraph-level bilingual content.
- [ ] After reload/restart, full-article translations remain available from `body_json`.
- [ ] Selection translation returns a real AI result in the translate tab after user action.
- [ ] With AI unconfigured, translate UI shows connect-AI guidance and does not show fake translations.
- [ ] ReaderStore and View layers do not directly call `anthropic.com`, create Anthropic `URLRequest`s, or construct Anthropic JSON.
- [ ] Tests use mock `AIService`/`AIClient`; no real API/network calls.
- [ ] `swift build`, `swift test`, and `./script/build_and_run.sh --verify` pass.

## Definition of Done

- Task G code is committed with the project commit-message convention.
- Trellis journal records implementation and verification results.
- Task G is archived after verification is green.
- Only after G passes and is archived may Task H be created and started.

## Technical Approach

Extend the existing Task F AI foundation rather than creating new transport or settings paths. `AnthropicService` constructs a structured JSON translation request through `Prompts.swift`, decodes a block-id-to-translation dictionary, and returns it through `AIService.translate`.

`ReaderStore` owns translation state and persistence. SwiftUI calls store actions and renders store state, while persistence continues through `ReaderRepository.saveItem`.

## Out of Scope

- Chat streaming.
- Remix templates.
- Persistent chat history.
- Alternate providers or local model implementations.
- New schema migrations.

## Technical Notes

- Binding spec: `.trellis/spec/guides/ai-integration-design.md`.
- Task F commit baseline: `80d541c`.
- Existing translation UI currently uses block translations or original text; replace demo behavior with explicit AI actions and state.
