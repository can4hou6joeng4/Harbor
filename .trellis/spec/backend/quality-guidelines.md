# Quality Guidelines

> Code quality standards for backend development.

---

## Overview

<!--
Document your project's quality standards here.

Questions to answer:
- What patterns are forbidden?
- What linting rules do you enforce?
- What are your testing requirements?
- What code review standards apply?
-->

(To be filled by the team)

---

## Forbidden Patterns

<!-- Patterns that should never be used and why -->

(To be filled by the team)

---

## Required Patterns

<!-- Patterns that must always be used -->

(To be filled by the team)

---

## Testing Requirements

<!-- What level of testing is expected -->

(To be filled by the team)

---

## Code Review Checklist

<!-- What reviewers should check -->

## Scenario: Reader AI integration v1

### 1. Scope / Trigger

- Trigger: any AI, model API, API-key, structured-output, or streaming work in `ReaderCore`.
- Binding guide: `.trellis/spec/guides/ai-integration-design.md`.
- Implementation boundary: production Anthropic HTTP/SSE knowledge must stay under `ReaderCore/AI/`.

### 2. Signatures

- Public service protocol: `AIService` exposes `isConfigured`, `validateConnection`, `summarize`, `translate`, `chat`, and `remix`.
- Transport protocol: `AIClient` exposes `send(_:)` and `stream(_:)`; tests inject mock clients.
- Key storage protocol: `APIKeyStoring` exposes load/save/delete/masked access; production implementation is `APIKeyStore`.
- UI/store boundary: SwiftUI views call `ReaderStore` actions; they do not construct Anthropic requests.

### 3. Contracts

- Anthropic requests use `POST https://api.anthropic.com/v1/messages`.
- Required headers: `content-type: application/json`, `x-api-key`, `anthropic-version: 2023-06-01`.
- Forbidden request fields: `temperature`, `top_p`, `top_k`, and `budget_tokens`.
- API keys live only in Keychain; model selection and enablement may use `UserDefaults`.
- Summary output decodes to `ReaderSummary` and persists through `ReaderRepository.saveItem`, reusing `summary_json`.

### 4. Validation & Error Matrix

- Missing or disabled key -> `AIError.notConfigured`, user-visible connect-AI guidance, no fake result.
- HTTP 401 -> `AIError.invalidAPIKey`, no retry.
- HTTP 429 -> `AIError.rateLimited`, retry after `retry-after` when present.
- HTTP 500/529 or transport failure -> bounded retry.
- Malformed structured output -> `AIError.decodingFailed`.

### 5. Good/Base/Bad Cases

- Good: `ReaderStore -> AIService -> AnthropicService -> AIClient`, then `ReaderStore -> ReaderRepository.saveItem`.
- Base: previews/tests use mock `AIService` or mock `AIClient`.
- Bad: SwiftUI or `ReaderStore` building Anthropic JSON, creating Anthropic `URLRequest`s, or referencing `anthropic.com`.
- Bad: showing generated-looking placeholder summaries when AI is unconfigured.

### 6. Tests Required

- SSE parser accumulates multiple text deltas and supports split `data:` lines.
- Structured summary response decodes to `ReaderSummary`.
- 429 retries with `retry-after`; 401 does not retry.
- Cancellation maps to a user-safe AI error.
- Long article prompt text is truncated before request construction.
- `ReaderStore` persists mock AI summaries through the repository.
- Keychain round trip and unconfigured state are covered.

### 7. Wrong vs Correct

#### Wrong

```swift
// SwiftUI or ReaderStore layer
let request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
```

#### Correct

```swift
// SwiftUI layer
store.generateSummary(for: item.id)

// ReaderCore/AI boundary
let summary = try await aiService.summarize(item)
```

(To be filled by the team)
