# 优化列表卡片缩略图与阅读时间布局

## Goal

修复列表第一条 PDF 卡片中右侧发布时间、缩略图、预计阅读时间堆叠过紧的问题，让 PDF 条目和后续文章条目的信息层级、留白和缩略图质感保持一致。

## Requirements

* 调整 `ItemListView` 的卡片布局，让预计阅读时间留在 footer 信息行，不再视觉上贴在右侧缩略图下方。
* PDF/附件缩略图需要有更清晰的边界或背景处理，避免白底 PDF 页面在选中态里像一块紧贴右侧的空白块。
* 缩略图尺寸和卡片正文列的间距保持稳定，不因为标题/摘要/时间变化造成卡片宽度或高度突兀跳动。
* 不改变 ReaderItem 数据模型、导入逻辑、PDF 解析、真实 AI、RSS/URL 采集逻辑。
* 保持后续文章、视频、无封面条目的现有视觉节奏，不引入大范围重构。

## Acceptance Criteria

* [x] 第一条 PDF 卡片中右侧缩略图与顶部时间、footer 阅读时间的视觉拥挤感明显降低。
* [x] PDF 缩略图在选中态和普通态下都有可辨识边界。
* [x] 阅读时间仍然可见，并与其他条目的位置/层级一致。
* [x] `swift build` 通过。
* [x] 如改动影响可测试逻辑则补测试；纯 SwiftUI 样式改动可记录未补测试原因。

## Definition of Done

* UI 样式修复提交。
* Trellis task archived。
* Journal 记录本次前置归档和 UI 修复结果。

## Technical Approach

优先在 `Sources/ReaderMacApp/Views/ItemListView.swift` 和必要的缩略图辅助组件中做小范围 SwiftUI 布局调整。保留现有 `CoverArtwork`/`CoverGradient` 路径，增加 PDF/附件预览的边框/阴影或背景，不拆分数据层。

## Decision (ADR-lite)

**Context**: PDF 缩略图是白底页面，和选中卡片浅色背景接近；同时 footer 阅读时间右对齐后在截图中贴近缩略图底部，形成一列紧凑信息。

**Decision**: 让卡片主体使用固定宽度缩略图槽并增加缩略图边界处理；footer 阅读时间保持在卡片信息行，但与缩略图槽留出稳定间距。

**Consequences**: 修复聚焦列表卡片视觉，不改变阅读详情页或导入行为。后续如果需要更强 PDF 视觉，可单独做 PDF 缩略图组件。

## Out of Scope

* 内容采集层改动。
* PDF 文本提取/封面生成逻辑改动。
* AI 接入。
* 全局列表重设计。

## Technical Notes

* 用户反馈来自当前 Reader App 截图：第一条 `reader-smoke-searchable.pdf` 卡片右侧区域比后续条目更紧凑。
* 相关代码：`Sources/ReaderMacApp/Views/ItemListView.swift`, `Sources/ReaderMacApp/Support/CoverGradient.swift`。
