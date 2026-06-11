# 补齐阅读交互闭环

## Goal

补齐已批准原型中阅读区的核心闭环交互，让用户可以在阅读时完成划词操作、创建高亮/笔记，并让阅读进度随滚动更新且能恢复阅读位置。这个任务聚焦阅读体验本身，不扩展到完整数据持久化、真实 AI 服务或内容采集。

## What I Already Know

* 当前 Reader macOS 应用已经完成主界面、窗口自适应、侧边栏、列表、阅读区和 AI 面板的原型级实现。
* 原型包含划词后的操作浮层，目标动作包括高亮、翻译、追问、笔记。
* 当前阅读正文只启用了 SwiftUI 系统文本选择：`ReaderDetailView.swift` 中 `ArticleView` 对正文使用 `.textSelection(.enabled)`。
* `ReaderStore` 已有 `addHighlight(itemID:quote:note:)`，但阅读区没有 UI 调用它，因此用户不能新建高亮或笔记。
* `ReaderStore` 已有 `setProgress(_:progress:)`，但当前只由“标记读完/重新开始”按钮触发。
* 当前 `ScrollView` 没有读取滚动偏移，也没有记录或恢复单篇文章的阅读位置。
* `ContentView` 已经调用 `ReaderStyle.contentLayout(...)`，响应式布局不是本任务的主要缺口。

## Scope Decision

用户已确认本任务先做本地内存态闭环：

* 实现划词浮层。
* 实现高亮和笔记创建。
* 实现追问和翻译入口。
* 实现滚动驱动阅读进度。
* 实现阅读位置恢复。
* 不包含正式持久化。
* 不包含真实 AI 服务接入。

## Assumptions

* 划词浮层应尽量贴近原型视觉，但优先保证可用和稳定。
* “翻译”和“追问”动作在本任务中接入现有 UI 状态或 toast/AI 面板入口，不要求接真实 AI 后端。
* 阅读进度以滚动位置估算即可，不要求按字符或段落精确计算。

## Requirements

* 用户在阅读正文中选择文本后，应出现原型风格的操作浮层。
* 操作浮层至少提供“高亮”“翻译”“追问”“笔记”四类入口。
* 点击“高亮”应调用现有 `ReaderStore.addHighlight` 并让高亮在正文中可见。
* 点击“笔记”应允许用户为选中文本输入简短备注，并保存为 `Highlight.note`。
* 点击“追问”应打开或聚焦 AI 面板，并带入当前选中文本作为上下文。
* 点击“翻译”应能对选中文本给出明确反馈；MVP 可先用现有双语/AI 面板能力承接。
* 阅读进度应随用户滚动更新，而不是只依赖“标记读完”按钮。
* 用户切换文章再返回时，应恢复该文章最近阅读位置。
* 阅读位置恢复应避免明显跳动或循环触发滚动更新。

## Acceptance Criteria

* [ ] 在阅读正文中划词后出现浮层，浮层位置靠近选区且不遮挡主工具栏。
* [ ] “高亮”动作会新增高亮，并在正文重新渲染后可见。
* [ ] “笔记”动作会保存 note，并能通过当前 UI 明确看到或确认已保存。
* [ ] “追问”动作会打开 AI 面板并携带选中文本上下文。
* [ ] “翻译”动作有明确用户反馈，不是静默无效按钮。
* [ ] 滚动阅读正文时，工具栏/底部显示的进度会跟随变化。
* [ ] 切换文章后再返回，滚动位置恢复到最近阅读点。
* [ ] `swift build` 通过。
* [ ] `swift test` 通过。
* [ ] `./script/build_and_run.sh --verify` 通过。

## Definition Of Done

* 实现符合现有 SwiftUI 文件组织和 `ReaderStore` 状态边界。
* 不引入大范围重构，不影响侧边栏、列表、窗口布局既有行为。
* 新增交互有针对性测试或可验证路径；无法自动化的 UI 行为需记录手动验证方式。
* 若发现必须调整数据模型，应说明是否只是内存态字段，还是为后续持久化预留。

## Out Of Scope

* 正式数据库/文件持久化。
* 真实 AI 摘要、翻译、问答服务接入。
* URL/RSS/PDF/Markdown 真实内容采集和解析。
* 多设备同步。
* 重做整体视觉风格或窗口布局。

## Technical Notes

* 主要代码入口：
  * `Sources/ReaderMacApp/Views/ReaderDetailView.swift`
  * `Sources/ReaderCore/ReaderStore.swift`
  * `Sources/ReaderCore/ReaderModels.swift`
  * `Sources/ReaderMacApp/Views/AIAssistantView.swift`
* 已确认的当前实现：
  * `ArticleView` 里正文块容器使用 `.textSelection(.enabled)`。
  * `ReaderStore.addHighlight` 会按 quote 去重并追加 `Highlight`。
  * `ReaderStore.setProgress` 会 clamp 到 `0...1`。
  * `ReaderItem` 已有 `progress` 和 `highlights` 字段。
* 待研究：
  * macOS SwiftUI 中可靠获取选中文本和选区位置的实现方式。
  * 是否需要窄桥接 AppKit 文本视图来实现原型级划词浮层。
  * 滚动位置读取/恢复应使用 SwiftUI preference、ScrollViewReader，还是 AppKit interop。
