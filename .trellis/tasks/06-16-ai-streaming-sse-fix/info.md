# Implementation Notes

## Root Cause

- Real `URLSession.AsyncBytes.lines` verification against `https://sub2api.bobochang.cn` showed 94 total lines, 0 blank separator lines, and 47 `data:` lines.
- Each individual `data:` payload was valid JSON, but joining all 47 payloads with `\n` produced invalid JSON and matched the observed `DecodingError.dataCorrupted` surfaced as `AIError.transport`.
- The old Anthropic and OpenAI-compatible parsers only flushed on blank line or `finish()`, so no-blank-line streams buffered multiple events into one invalid payload.

## Fix

- `AnthropicSSEParser` now flushes a buffered event on blank line, a new `event:` line, or stream finish.
- `OpenAICompatibleSSEParser` now flushes complete `data:` events even when they arrive consecutively without blank lines, while still allowing split multi-line `data:` payloads.
- Malformed single data events are skipped so streaming can continue; provider error events still throw `AIError.transport`.

## Verification

- Added regression tests for no-blank-line Anthropic streams with `message_start`, `content_block_start`, `ping`, multiple `content_block_delta`, `message_delta`, `message_stop`, and `[DONE]`.
- Added regression tests for no-blank-line OpenAI-compatible streams.
- Added regression tests that malformed single data events are skipped and provider error payloads still throw.
- `swift build` passed.
- `swift test` passed: 91 tests, 0 failures.
- `./script/build_and_run.sh --verify` passed.

