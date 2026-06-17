# 修复新手引导聚焦遮罩

## Goal

修复 Reader 新手引导当前“整屏灰色遮罩 + 目标描边”导致目标区域仍被遮住的问题，并修复第 2、3 步在目标实际可见时误判为不可见 fallback 的问题，让引导表现为真正的 spotlight：目标区域清晰透出，其他区域弱化。

## What I already know

- 用户提供截图显示当前新手引导每一步都覆盖灰色遮罩，目标 UI 没有真正透出。
- 第 2 步“添加内容”和第 3 步“管理 RSS 订阅源”截图显示 fallback 文案“当前窗口下目标区域不可见”，但对应 UI 在实际窗口中应可见。
- 当前 `OnboardingOverlay` 只绘制全屏 `Rectangle` 遮罩，再在目标 frame 上画描边；没有做遮罩挖空。
- 当前 `onboardingTarget(_:)` 使用 `anchorPreference`。同一 target 若被内外层同时写入，`PreferenceKey.reduce` 使用后写覆盖，可能让外层 sidebar 锚点覆盖内层 add/RSS 锚点或导致锚点空间不稳定。
- 现有 frontend spec 已新增 SwiftUI onboarding overlays 约定：根视图负责 overlay z-order，目标不可见时才 fallback，打开时屏蔽单键快捷键。

## Assumptions

- 用户希望保留全屏弱化背景，只让当前目标区域不被遮罩覆盖，而不是完全移除遮罩。
- 本任务不改变五步引导内容、不新增新手引导状态机，只修视觉与目标定位。
- SwiftUI 原生 `Canvas` / even-odd fill 可以满足 spotlight 遮罩，无需第三方依赖。

## Open Questions

- None.

## Requirements

- 新手引导 overlay 必须对当前目标区域做透明挖空，使对应 UI 能清楚看到。
- 非目标区域仍应有遮罩/弱化，保持用户注意力集中。
- 目标区域应保留描边或高亮，但不应把目标内容盖住。
- 第 2 步“添加内容”和第 3 步“RSS 订阅源”在默认窗口布局下不应误判为不可见。
- 只有目标锚点真的缺失、尺寸无效或完全在窗口外时，才显示 fallback 文案。
- 卡片位置应尽量避开目标区域，不能遮挡当前被说明的控制。
- 现有“上一页 / 下一页 / 跳过 / 完成”控制继续可用。

## Acceptance Criteria

- [x] 第 1、4、5 步目标区域从遮罩中透明露出。
- [x] 第 2、3 步不再错误显示“当前窗口下目标区域不可见”。
- [x] 每一步仍有清晰边框或高亮提示当前目标。
- [x] 窗口尺寸变化时，若目标不可见仍有 fallback 展示。
- [x] `swift build` 通过。
- [x] `swift test` 通过。
- [x] `./script/build_and_run.sh --verify` 通过。

## Verification

- `swift build` passed on 2026-06-18.
- `swift test` passed on 2026-06-18: 94 tests, 0 failures.
- `./script/build_and_run.sh --verify` passed on 2026-06-18.
- `git diff --check` passed on 2026-06-18.
- Diff secret scan passed on 2026-06-18.
- Manual window screenshots verified all five onboarding steps:
  - step 1 sidebar spotlight cutout
  - step 2 add-content spotlight cutout with no fallback copy
  - step 3 RSS spotlight cutout with no fallback copy
  - step 4 reader spotlight cutout
  - step 5 AI/settings spotlight cutout

## Definition of Done

- 相关 SwiftUI 改动已实现并符合现有 `OnboardingOverlay` 与 `ReaderStyle` 风格。
- 必要测试或可验证检查已补充。
- Trellis 任务归档并记录会话。

## Out of Scope

- 不重做新手引导文案和步骤数量。
- 不添加第三方 onboarding / spotlight 框架。
- 不改变首次显示和完成持久化逻辑。
- 不实现用户可在引导中直接操作底层 UI。

## Technical Notes

- 重点文件：
  - `Sources/ReaderMacApp/Views/OnboardingOverlay.swift`
  - `Sources/ReaderMacApp/Views/SidebarView.swift`
  - `Sources/ReaderMacApp/Views/ContentView.swift`
  - `Sources/ReaderMacApp/Views/AIAssistantView.swift`
  - `Sources/ReaderMacApp/Views/ReaderDetailView.swift`
- 相关规范：
  - `.trellis/spec/frontend/component-guidelines.md`
