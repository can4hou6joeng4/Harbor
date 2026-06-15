# AI 接入设计指南归档

## Goal

把上一轮遗留的 AI 接入约束设计文档纳入 Trellis spec，并让 guides index 能正确发现该文档。此任务只做设计归档，不实现真实 AI。

## Requirements

* 保留 `.trellis/spec/guides/ai-integration-design.md` 作为后续 Task F/G/H 的约束性设计指南。
* 在 `.trellis/spec/guides/index.md` 中登记 AI Integration Design Guide。
* 明确本任务不改应用代码，不接入 Anthropic，不实现设置页、Keychain、摘要、翻译、对话或二创。
* 提交并归档该 Trellis task，清理上一轮遗留的未提交 spec 文件。

## Acceptance Criteria

* [x] `ai-integration-design.md` 被 Git 跟踪。
* [x] guides index 能链接到该文档。
* [x] 工作区不再留下 AI 设计文档相关未提交改动。
* [x] 不包含任何真实 AI 接入代码改动。

## Definition of Done

* Docs-only commit 完成。
* Trellis task archived。
* 后续 UI 修复可以在干净边界上开始。

## Out of Scope

* 真实 AI 接入。
* Anthropic API 调用、Keychain、设置页、流式 SSE、摘要/翻译/对话/二创实现。
* C/D/E 内容采集层代码变更。

## Technical Notes

* Dirty files before task creation: `.trellis/spec/guides/ai-integration-design.md`, `.trellis/spec/guides/index.md`.
* User requested this cleanup before implementing the current UI card style fix.
