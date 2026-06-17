# RSS订阅添加与新手引导

## Goal

修复当前侧边栏“订阅源”添加入口难以发现/难以点击的问题，并为 Reader 增加首次进入与应用内可重新打开的新手引导，让用户能顺利完成核心工作流：添加内容、添加 RSS 订阅、阅读/标记、使用 AI 与设置。

## What I already know

- 用户反馈：尝试添加/编辑“RSS订阅源”时，似乎无法点击到该栏目的 `+` 进行添加。
- 用户希望：首次进入应用时有“新手引导”，应用内也保留一个入口供用户重新熟悉。
- 当前 `SidebarView` 的“订阅源”section 使用 `SidebarSection(title: "订阅源", actionIcon: "plus") { store.subscriptionsOpen = true }`。
- `SidebarSection` 的 `+` 按钮仅在整个 section hover 时显示：`.opacity(hovering ? 1 : 0)`，按钮尺寸为 20，命中区域小且默认不可见。
- 当前 `SubscriptionsModal` 已存在，包含“添加 RSS 链接…”输入框和“订阅”按钮，调用 `ReaderStore.addRSSFeed(_:)`。
- 当前命令面板已有“管理订阅源”命令，但侧边栏入口对普通用户仍不直观。
- 当前代码没有搜索到现成 onboarding / guide / 新手引导模块。
- `ReaderStore` 已有 RSS 同步状态：`subscriptionsOpen`、`isSyncingFeeds`、`feedSyncErrors`、`addRSSFeed(_:)`、`syncFeeds()`。
- 内容采集设计指南要求 View 层不直接调 Capture 服务，一律经 `ReaderStore`；RSS 订阅管理 UI 已属于 Task D 范围。

## Assumptions

- “点不到 +”的主要原因是 section action 依赖 hover 可见性，且按钮尺寸/命中区域太小；不一定是 `SubscriptionsModal` 或后端添加逻辑坏掉。
- 新手引导应为轻量产品内帮助，不应引入复杂外部依赖或营销式落地页。
- 首次引导状态应本地持久化，避免每次启动都打扰用户。

## Open Questions

- None.

## Requirements (evolving)

- 订阅源添加入口必须常驻可见或有明确可点击区域，不能只依赖 hover 才显示。
- 订阅源添加入口必须打开现有订阅管理弹窗，并聚焦到 RSS URL 输入流程。
- 应用内必须保留一个可重新打开新手引导的入口。
- 首次进入应用时应展示交互式逐步高亮引导或明显的开始入口。
- 新手引导采用交互式逐步高亮方案：逐步突出侧边栏、添加内容、RSS 订阅、阅读区、AI/设置等核心区域，并提供“下一步 / 上一步 / 跳过 / 完成”控制。
- 引导应尽量复用现有 SwiftUI overlay/scrim 风格，不引入第三方 onboarding 框架。
- 交互式引导 MVP 包含 5 步：
  1. 侧边栏：认识收件箱、未读、收藏等视图。
  2. 添加内容：解释顶部 `+` 可添加 URL、附件、Markdown。
  3. RSS 订阅源：高亮订阅源入口和管理弹窗入口。
  4. 阅读区：解释阅读、进度、收藏/删除等核心操作。
  5. AI/设置：解释 AI 助手、模型设置和应用设置入口。

## Acceptance Criteria (evolving)

- [x] 用户无需悬停猜测，也能在侧边栏找到并点击“添加/管理订阅源”入口。
- [x] 点击订阅源入口后，能打开 `SubscriptionsModal` 并添加 RSS 链接。
- [x] 应用首次启动时能看到新手引导或明确的新手入口。
- [x] 用户在应用内能再次打开新手引导。
- [x] 新手引导关闭后不会在后续启动中反复打扰，除非用户主动重新打开。
- [x] 新手引导能逐步高亮核心 UI 区域，并允许用户前进、后退、跳过和完成。
- [x] 新手引导包含已确认的 5 步 MVP：侧边栏、添加内容、RSS 订阅源、阅读区、AI/设置。
- [x] 当窗口尺寸变化或目标区域不可见时，引导仍有可读的 fallback 展示，不遮挡主要控制。
- [x] `swift build`、`swift test`、`./script/build_and_run.sh --verify` 通过。

## Verification

- 2026-06-17: `swift build` passed.
- 2026-06-17: `swift test` passed, 94 tests.
- 2026-06-17: `./script/build_and_run.sh --verify` passed.

## Definition of Done

- 相关 UI 改动已实现并符合现有 SwiftUI 组件风格。
- 必要的状态持久化和测试已补充。
- Trellis 任务归档并记录会话。

## Out of Scope (draft)

- 不做 OPML 导入/导出。
- 不重做 RSS 解析/同步后端。
- 不引入第三方 onboarding 框架。
- 不做全量教程网站或外部文档系统。
- 不要求引导步骤实际替用户执行添加 RSS 或发起网络同步；引导只负责解释和定位入口。

## Decision (ADR-lite)

**Context**: 用户希望首次进入时能被引导熟悉 Reader，并且后续能从应用内重新打开。当前 RSS 添加入口隐藏在 hover 状态下，已经造成入口不可发现/难以点击。

**Decision**: 采用交互式逐步高亮引导，而不是单页帮助弹窗。RSS 入口同时改为常驻或明确可点击，不依赖 hover 才可见。

**Consequences**: 用户学习成本更低，但实现需要在 SwiftUI 中维护引导步骤、目标区域锚点、窗口变化 fallback 与首次展示状态。MVP 不做复杂动画或自动执行操作，优先保证稳定、可读、可跳过。

## Technical Notes

- 重点文件：
  - `Sources/ReaderMacApp/Views/SidebarView.swift`
  - `Sources/ReaderMacApp/Views/OverlaysView.swift`
  - `Sources/ReaderMacApp/Views/ContentView.swift`
  - `Sources/ReaderCore/ReaderStore.swift`
  - `Sources/ReaderMacApp/Support/Icon.swift`
  - `Sources/ReaderMacApp/Views/SmallControls.swift`
- 相关规范：
  - `.trellis/spec/frontend/component-guidelines.md`
  - `.trellis/spec/frontend/state-management.md`
  - `.trellis/spec/guides/content-capture-design.md`
