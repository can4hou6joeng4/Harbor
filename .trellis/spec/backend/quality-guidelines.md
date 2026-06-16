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

## Scenario: macOS local packaging

### 1. Scope / Trigger

- Trigger: packaging the SwiftPM app into a distributable local macOS `.app` or `.dmg`.
- Applies to `script/package_app.sh`, app bundle metadata, icon generation, codesigning, hardened runtime, entitlements, and DMG validation.
- Packaging must preserve the development runner `script/build_and_run.sh`; do not replace debug-run behavior with release packaging side effects.

### 2. Signatures

- Packaging command: `./script/package_app.sh [--regenerate-icon]`.
- Environment overrides:
  - `SHORT_VERSION`: `CFBundleShortVersionString`, default `0.1.0`.
  - `BUILD_NUMBER`: `CFBundleVersion`, default `git rev-list --count HEAD`.
  - `SIGN_IDENTITY`: codesign identity, default `-` for ad-hoc.
  - `ENABLE_APP_SANDBOX`: `0|1`, default `0` for local ad-hoc Keychain safety.
- Icon generator command path: `script/make_app_icon.swift`, compiled by the packaging script when regenerating icons.

### 3. Contracts

- Output app path: `dist/Reader.app`.
- Output DMG path: `dist/Reader.dmg`.
- Bundle executable remains `ReaderMacApp`; display/bundle name is `Reader`.
- Bundle identifier remains `com.bobochang.ReaderMacApp`.
- Required `Info.plist` fields include executable, identifier, name/display name, package type `APPL`, short version, build version, minimum macOS `13.0`, high-resolution flag, icon file `AppIcon`, app category `public.app-category.news`, copyright, and `NSPrincipalClass`.
- `Resources/AppIcon.icns` is a committed generated artifact; `script/make_app_icon.swift` is the source of truth for reproducing it without external images or third-party libraries.
- `Resources/Reader.entitlements` is the sandbox template and must include app sandbox, network client, and user-selected read-write file permissions.
- Local ad-hoc packaging signs with hardened runtime and non-sandbox local entitlements by default. Enable sandbox only after real signing/provisioning is available and Keychain has been verified.

### 4. Validation & Error Matrix

- Missing `swift`, `swiftc`, `sips`, `iconutil`, `codesign`, `hdiutil`, or `plutil` -> packaging script exits before mutating the bundle.
- `plutil -lint dist/Reader.app/Contents/Info.plist` fails -> invalid bundle metadata; do not ship.
- `codesign --verify --strict dist/Reader.app` fails -> invalid signature; do not ship.
- `hdiutil verify dist/Reader.dmg` fails -> invalid image; recreate before shipping.
- Ad-hoc + app sandbox causes Keychain crash or `errSecMissingEntitlement` -> keep local default non-sandbox and record evidence in the task `info.md`.

### 5. Good/Base/Bad Cases

- Good: package script performs release build, assembles bundle, copies committed icon, writes full plist, signs with hardened runtime, verifies signature, creates DMG, and verifies DMG.
- Good: launch validation uses `open -n dist/Reader.app` plus `pgrep -x ReaderMacApp`.
- Good: DMG validation mounts the image and checks for `Reader.app` plus an `Applications` symlink.
- Base: ad-hoc local packaging is acceptable for same-machine testing; Developer ID notarization is a separate distribution step.
- Bad: enabling sandbox by default on ad-hoc builds without a real Keychain round-trip.
- Bad: committing `dist/` outputs; `dist/` remains ignored.
- Bad: depending on external images for the app icon.

### 6. Tests Required

- Run `./script/package_app.sh --regenerate-icon` at least once when changing packaging, icon generation, signing, or entitlements.
- Verify `codesign --verify --strict dist/Reader.app`.
- Inspect `codesign -dvvv --entitlements :- dist/Reader.app` for hardened runtime and expected entitlements.
- Verify `plutil -p dist/Reader.app/Contents/Info.plist` for bundle metadata.
- Verify `hdiutil verify dist/Reader.dmg` and mount contents.
- Run `swift build`, `swift test`, and `./script/build_and_run.sh --verify` to ensure packaging changes did not break development flow.

### 7. Wrong vs Correct

#### Wrong

```bash
# Ships a debug bundle with no icon, no full plist, and no signature.
swift build
cp .build/debug/ReaderMacApp dist/Reader.app/Contents/MacOS/
```

#### Correct

```bash
./script/package_app.sh --regenerate-icon
codesign --verify --strict dist/Reader.app
hdiutil verify dist/Reader.dmg
```

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
- Implementation boundary: production provider HTTP/SSE knowledge must stay under `ReaderCore/AI/`.

### 2. Signatures

- Public service protocol: `AIService` exposes `isConfigured`, `validateConnection`, `summarize`, `translate`, `chat`, and `remix`.
- Transport protocol: `AIClient` exposes `send(_:)` and `stream(_:)`; tests inject mock clients.
- Key storage protocol: `APIKeyStoring` exposes load/save/delete/masked access; production implementation is `APIKeyStore`.
- UI/store boundary: SwiftUI views call `ReaderStore` actions; they do not construct provider HTTP requests, JSON bodies, or headers.

### 3. Contracts

- Anthropic requests use Messages API. Default endpoint is `POST https://api.anthropic.com/v1/messages`; custom Anthropic-compatible base URLs normalize host, `/v1`, or full `/v1/messages` input to the messages endpoint.
- Anthropic required headers: `content-type: application/json`, `anthropic-version: 2023-06-01`, plus either `x-api-key` or `authorization: Bearer <token>` according to `AnthropicAuthMode`.
- Anthropic model strings may use a `[1m]` suffix; request construction strips the suffix from the JSON `model` and adds `anthropic-beta: context-1m-2025-08-07`. Additional beta values are comma-separated in settings and merged into the same header.
- OpenAI-compatible required headers: `content-type: application/json`, `authorization: Bearer <key>`.
- Forbidden request fields: `temperature`, `top_p`, `top_k`, and `budget_tokens`.
- API keys/tokens live only in Keychain and must be isolated per provider; provider/model/base URL/auth mode/beta selection and enablement may use `UserDefaults`.
- Summary output decodes to `ReaderSummary` and persists through `ReaderRepository.saveItem`, reusing `summary_json`.
- Translation output decodes to `[String: String]` keyed by `ContentBlock.id.uuidString`; full-article translations persist by writing `ContentBlock.translation` back through `ReaderRepository.saveItem`, reusing `body_json`.
- Chat and remix return `AsyncThrowingStream<String, Error>` token streams; request construction stays in `Prompts.swift`, and production streaming stays behind `ReaderCore/AI` services plus `AIClient`.
- Chat messages and remix drafts are session-local UI state only; they must not be persisted through `ReaderRepository`.
- Streaming SSE parsers must not rely on blank-line event separators from `URLSession.AsyncBytes.lines`. They must flush buffered Anthropic events on blank line, new `event:` line, or end-of-stream; OpenAI-compatible streams must support consecutive complete `data:` events without blank lines while still allowing split multi-line `data:` payloads.
- Malformed single streaming data events are skipped so the rest of the stream can continue; provider-level error events still throw `AIError.transport`.

### 4. Validation & Error Matrix

- Missing or disabled key -> `AIError.notConfigured`, user-visible connect-AI guidance, no fake result.
- HTTP 401 -> `AIError.invalidAPIKey`, no retry.
- HTTP 429 -> `AIError.rateLimited`, retry after `retry-after` when present.
- HTTP 500/529 or transport failure -> bounded retry.
- Malformed structured output -> `AIError.decodingFailed`.
- Malformed single SSE data event -> skip event and continue stream.
- Anthropic `type == "error"` or OpenAI-compatible `{"error": ...}` SSE payload -> `AIError.transport`.
- Streaming chat/remix cancellation -> `AIError.cancelled` or silent UI cancellation when the local task was intentionally cancelled.

### 5. Good/Base/Bad Cases

- Good: `ReaderStore -> AIService -> ProviderService -> AIClient`, then `ReaderStore -> ReaderRepository.saveItem`.
- Good: `ReaderStore.sendMessage` appends a user message and a blank assistant message, then fills the assistant text from streamed tokens.
- Good: `ReaderStore.generateRemix` fills `remixOutput` from streamed tokens and leaves repository state unchanged.
- Good: parser tests include real `URLSession.AsyncBytes.lines` shapes where `event:` and `data:` lines arrive consecutively without blank separators.
- Base: previews/tests use mock `AIService` or mock `AIClient`.
- Bad: buffering all `data:` lines until `finish()` and decoding them as one JSON object; real streams may contain many complete JSON events with no blank-line separators.
- Bad: SwiftUI or `ReaderStore` building provider JSON, creating provider `URLRequest`s, setting provider headers, or referencing provider endpoint URLs.
- Bad: showing generated-looking placeholder summaries when AI is unconfigured.
- Bad: reintroducing local fake chat/remix drafts when AI is unconfigured or unavailable.

### 6. Tests Required

- Anthropic and OpenAI-compatible SSE parsers accumulate multiple text deltas and support split `data:` lines where applicable.
- Anthropic and OpenAI-compatible SSE parser tests must cover no-blank-line streams, malformed single data events that are skipped, and provider error events that still throw.
- Anthropic custom connection tests assert endpoint normalization, auth header mode, `[1m]` beta mapping, and anyrouter-style mock request shape without real network calls.
- Structured summary response decodes to `ReaderSummary`.
- 429 retries with `retry-after`; 401 does not retry.
- Cancellation maps to a user-safe AI error.
- Long article prompt text is truncated before request construction.
- `ReaderStore` persists mock AI summaries through the repository.
- `ReaderStore` persists mock full-article translations through `body_json`; selection translations stay visible in panel state and do not mutate the article body.
- `ReaderStore` streams mock chat tokens into the current assistant message and cancels in-flight chat when the selected item changes.
- `ReaderStore` streams mock remix tokens into `remixOutput` and asserts repository items are unchanged.
- Keychain round trip, provider key isolation, and unconfigured state are covered.

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

#### Wrong

```swift
// Parser waits until finish() and decodes every data line as one JSON object.
let payload = dataLines.joined(separator: "\n")
let event = try JSONDecoder().decode(StreamPayload.self, from: Data(payload.utf8))
```

#### Correct

```swift
// Parser treats a new SSE event boundary as the signal to decode the previous event.
if line.hasPrefix("event:") {
    let output = try flush()
    eventName = parsedEventName
    return output
}
```

(To be filled by the team)
