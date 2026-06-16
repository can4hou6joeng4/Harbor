# 交互可用性收尾:条目删除与键盘导航

## Goal

补齐两处「原型有、原生实现还缺」的基础可用性:① 让用户能**删除**已保存的条目(目前完全删不掉);② 补上列表的**单键键盘导航**(j/k 选择、f 收藏、⌫ 删除)。范围仅限这两项交互,不扩展归档/稍后读等新数据状态,不动 AI、采集、持久化既有行为。

## What I Already Know

* `ReaderStore` **没有任何删除方法**(`grep "func deleteItem|archive|removeItem"` 无结果),UI 也没有删除入口——条目一旦保存无法移除。
* 持久化层**已具备删除能力**:`ReaderRepository.deleteItem(id:)` 已实现,`GRDBRepository.deleteItem` 内已处理 FTS 删除,且 schema v1 的 `highlight`/`item_tag` 外键为 `ON DELETE CASCADE`,删除条目会自动清理其高亮与标签关联。
* 键盘:目前只有 `⌘N`(添加)、`⌘K`(命令面板),通过 `ReaderMacApp.swift` 的 `.commands { CommandMenu("Reader") }` 实现。**没有** j/k/f/⌫ 单键导航。
* 已完成、**本任务不重复做**:设置「测试连接」(`AISettingsView.testConnection` → `validateConnection`)、RSS 摘要型条目「抓取全文」按钮(`ReaderDetailView` → store 去 `summaryOnlyMarker`)。
* 阅读区正文选择/划词由 `SelectableArticleText`(NSViewRepresentable)处理,滚动由 `ReaderScrollObserver` 处理——已有 AppKit 互操作先例可参考。
* 目标平台 `macOS 13`:`View.onKeyPress` 是 macOS 14+,**不可用**;单键监听需走 `NSEvent` 本地 keyDown 监视器或等价 AppKit 桥接(参考现有 NSViewRepresentable 用法)。
* 列表与选中态:`ReaderStore.visibleItems`(过滤+排序后的可见列表)、`selectedItemID`、`selectItem(_:)` 已存在;删除后需重选合理邻居。

## Scope Decision

* 做:条目删除(store 方法 + UI 入口 + 确认 + 删除后重选)。
* 做:列表单键导航 j(下一条)、k(上一条)、f(收藏/取消收藏当前)、⌫/delete(删除当前,接删除流程)。
* 不做:归档(已归档)/稍后读的真实数据状态与切换。
* 不做:批量多选删除、撤销(undo)栈。
* 不做:改动 AI/采集/持久化既有逻辑。

## Requirements

* `ReaderStore` 新增 `deleteItem(_ id:)`:调用 `repository.deleteItem(id:)` 异步落库;同步从内存 `items` 移除;若删除的是 `selectedItemID`,重选**当前可见列表中的相邻条目**(优先下一条,无则上一条,再无则置 nil);失败有 toast。
* 删除 UI 入口至少两处:列表行 `contextMenu`(右键)「删除」,以及阅读区工具栏「更多」菜单「删除」。
* 删除为破坏性操作,**需二次确认**(`confirmationDialog`/alert),确认后才删;删除后给 toast。
* 单键导航(仅在**未聚焦文本输入**且无模态弹层时生效,避免与搜索框/AI 输入/命令面板冲突):
  * `j` → 选中可见列表下一条;`k` → 上一条;到边界不绕回。
  * `f` → 切换当前选中条目的收藏(复用 `toggleFavorite`)。
  * `⌫`(delete)→ 删除当前选中条目(走上面的删除+确认流程)。
* `⌘N` / `⌘K` 现有快捷键保持不变。

## Acceptance Criteria

* [ ] 列表右键与阅读区「更多」都能删除条目,删除前有确认。
* [ ] 删除后:该条目从列表消失、从数据库消失(**杀进程重开不再出现**),其高亮/标签关联一并清除。
* [ ] 删除当前选中条目后,自动重选相邻条目(或在空列表时进入空态),不崩溃。
* [ ] `j`/`k` 能在列表上下移动选择;`f` 能切换收藏;`⌫` 能删除当前(经确认)。
* [ ] 在搜索框 / AI 输入框聚焦时,按 j/k/f 不触发导航(输入正常)。
* [ ] `swift build`、`swift test`、`./script/build_and_run.sh --verify` 全绿。
* [ ] 新增针对性测试:`deleteItem` 从内存与(mock/内存仓储)持久层移除、删除后选中态重选逻辑;无法自动化的单键行为记录手动验证方式。

## Out Of Scope

* 归档/稍后读真实状态、批量删除、撤销栈。
* 任意 AI / 采集 / RSS / 附件 行为变更。
* 整体视觉风格或窗口布局调整。

## Technical Notes

* 主要入口文件:
  * `Sources/ReaderCore/ReaderStore.swift`(加 `deleteItem`,复用 `persist {}`、`selectItem`、`visibleItems`)
  * `Sources/ReaderMacApp/Views/ItemListView.swift`(行 `contextMenu`)
  * `Sources/ReaderMacApp/Views/ReaderDetailView.swift`(工具栏「更多」菜单)
  * `Sources/ReaderMacApp/App/ReaderMacApp.swift` 或一个 AppKit keyDown 监视器(单键导航;注意 macOS 13 无 `onKeyPress`)
* 删除已落库能力现成:`ReaderRepository.deleteItem(id:)` / `GRDBRepository.deleteItem`(含 FTS 清理 + 外键级联),store 只需调用 + 维护内存与选中态。
* 单键监听实现建议:`NSEvent.addLocalMonitorForEvents(matching: .keyDown)`,在 `firstResponder` 为 `NSTextView`/`NSTextField` 时直接放行(返回 event),否则拦截 j/k/f/⌫;或参考 `ReaderScrollObserver` 的 NSViewRepresentable 思路。务必处理监视器的注册/注销生命周期。
* 确认对话框:破坏性删除用 `confirmationDialog`,文案含条目标题。
