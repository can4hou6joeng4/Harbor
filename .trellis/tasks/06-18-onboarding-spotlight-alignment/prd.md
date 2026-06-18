# 修复新手引导挖洞与真实控件对齐

## Goal

修复新手引导(`OnboardingOverlay`)聚焦挖洞**与真实控件错位**的问题:挖洞高亮框必须精准套住每一步对应的真实 UI 元素(尤其「添加内容 +」按钮、「订阅源」标题行的 + 按钮)。当前部分步骤挖洞飘在空白处或偏移到相邻区域,且 AI 步只高亮了标签栏、漏了左下角齿轮。

## What I Already Know(已定位的根因,基于真机截图核实)

* **截图证据**:用户真机运行 v0.1.x,5 步逐屏截图显示:第 1 步(资料库/侧栏)、第 4 步(阅读区)、第 5 步(AI 标签栏)大块对齐基本正常;**第 2 步(添加内容)挖洞是个小白条飘在侧栏顶部、没套住 + 按钮**;**第 3 步(管理 RSS)挖洞偏到「已归档/订阅源」之间、没套住订阅源标题行**。
* **`.addContent` 根本没挂到真实控件**:`grep onboardingTarget` 全仓库只有 `.sidebar`(SidebarView:155)、`.reader`(ReaderDetailView:33)、`.rss`(SidebarView:49 的 `headerOnboardingTarget`)、`.aiSettings`(两处)。真实「添加内容 +」按钮在 `SidebarView.swift:23`(`IconButton(icon:"plus", title:"添加内容"…) { store.addModalOpen = true }`),**未挂 `.onboardingTarget(.addContent)`**。
* 因为没有 addContent 目标,`OnboardingOverlay.derivedTargetFrame(for:.addContent)` 用**硬编码魔法偏移**(`x: sidebarFrame.maxX - 47, y: sidebarFrame.minY + 14, 34×34`)+ `adjustedSpotlightFrame` 再二次偏移(`maxX-18-26, minY+21`)猜按钮位置 —— 与真实按钮对不上,导致第 2 步错位。
* **`.aiSettings` 重复挂两处**:`SidebarView.swift:146`(左下角齿轮)与 `AIAssistantView.swift:49`(右侧 AI 标签栏)。`OnboardingTargetPreferenceKey.reduce` 用 `next.area >= current.area` 取面积大者 → 标签栏覆盖齿轮,齿轮永不被高亮;而第 5 步文案同时提到「标签栏」和「左下角齿轮」,语义与高亮不一致。
* **坐标空间嫌疑**:`ContentView` 在最外层 ZStack 上 `.coordinateSpace(name: OnboardingCoordinateSpace.name)`(L59),内层 `GeometryReader` 带 `.ignoresSafeArea(.container, edges:.top)`(L39);而 `OnboardingOverlay` 用 `GeometryReader { proxy in proxy.frame(in:.local) }` 当作 screen 来摆放挖洞/卡片。两套坐标原点若存在顶部 inset 差,会让小目标明显错位(大块面板看起来仍大致对),与截图征兆吻合。需核查并统一:**挖洞/卡片定位所用的 screen 原点,必须与 targets 测量所用的命名坐标空间一致**。

## Scope Decision

做:把所有引导步骤的 target 直接挂到**真实控件**;移除/弃用 `derivedTargetFrame` 与魔法偏移;修坐标空间一致性;处理 `.aiSettings` 多目标。
不做:改引导步骤数量/文案主旨(文案可微调以匹配实际高亮)、改其它功能、改 DMG/发布。

## Requirements

1. **真实控件挂 target,删除魔法偏移**
   * 给 `SidebarView.swift:23` 的「添加内容 +」`IconButton` 挂 `.onboardingTarget(.addContent)`。
   * 删除 `OnboardingOverlay.derivedTargetFrame(for:)` 中 addContent 的硬编码推导,以及 `adjustedSpotlightFrame(.addContent)` 里基于猜测的二次偏移;改为直接用实测 frame(必要的微小 padding 可保留,但不得用绝对坐标猜位置)。
   * 复核 `.rss`:`headerOnboardingTarget: .rss` 已挂在订阅源 `SidebarSection` 的 22pt header(含右侧 + 按钮)。确认它测出的 frame 就是订阅源标题行;若挖洞仍偏,根因应在坐标空间(见 4),而非再加偏移。
2. **`.aiSettings` 多目标处理(二选一,推荐 a)**
   * a) **拆成两个目标**:新增 `.aiPanel`(右侧标签栏)与 `.aiSettings`(左下角齿轮),第 5 步同时高亮两者(挖洞支持多框,或合并成包含二者的最小外接框),文案与高亮一致;或
   * b) 第 5 步只高亮一个并改文案,使描述与高亮严格对应,移除另一处重复挂载以免 reduce 吞并。
3. **坐标空间一致性**
   * 让 `OnboardingOverlay` 摆放挖洞/卡片时使用的"屏幕系"与 `targets` 的测量系**同源**:overlay 也用 `GeometryReader { proxy in proxy.frame(in: .named(OnboardingCoordinateSpace.name)) }`(而非 `.local`),或在 ContentView 用一个包裹同一坐标空间的容器统一二者;消除 `.ignoresSafeArea(.top)` 带来的原点差。
   * 验证:挖洞框中心与目标控件中心在各窗口尺寸下都对齐(±2pt)。
4. **保持既有行为**:卡片避让定位、跳过/上一步/下一步·完成、首次门控、可重放、暗色适配不回归。

## Acceptance Criteria

* [ ] 全部 5 步在**真机运行**下挖洞精准套住对应控件:① 侧栏 ② **添加内容 + 按钮**(套住按钮本身,不再飘空) ③ **订阅源标题行/其 + 按钮** ④ 阅读区 ⑤ AI(标签栏 + 齿轮按 §2 方案,文案与高亮一致)。**必须以真机/真实 ContentView 渲染验证,不得只用合成坐标的离屏渲染**(后者正是上轮漏检的原因)。
* [ ] `grep onboardingTarget` 能看到 `.addContent` 挂在 `SidebarView` 的添加按钮上;`OnboardingOverlay` 不再含 addContent 的绝对坐标魔法偏移。
* [ ] `.aiSettings` 不再因 reduce 取面积大者而吞并齿轮(按 §2 落地)。
* [ ] overlay 定位坐标系与 targets 测量坐标系同源(代码层面可见,且对齐验证通过)。
* [ ] `swift build && swift test && ./script/build_and_run.sh --verify` 全绿;引导既有交互(跳过/导航/门控/重放/暗色)不回归。
* [ ] 手动验证记录(info.md):附**真机**逐步对齐结果(截图或逐步坐标核对:挖洞 frame vs 目标控件 frame 差值)。

## Definition Of Done

* 5 步挖洞与真实控件对齐;添加内容、RSS 两步不再错位;AI 步高亮与文案一致。
* 删除了基于猜测的硬编码偏移,改为实测 frame;坐标系统一。
* 不影响其它功能与既有引导交互。

## Out Of Scope

* 引导步骤增减、整体重写;其它界面/功能;DMG/发布/自更新。

## Technical Notes

* 关键文件:`Sources/ReaderMacApp/Views/OnboardingOverlay.swift`(删 derived/魔法偏移、坐标系)、`Sources/ReaderMacApp/Views/SidebarView.swift`(加 `.addContent` 到 L23 按钮、复核 `.rss`/`.aiSettings`)、`Sources/ReaderMacApp/Views/AIAssistantView.swift`(`.aiSettings`→`.aiPanel` 视方案)、`Sources/ReaderMacApp/Views/ContentView.swift`(坐标空间/overlay 容器)、必要时 `OnboardingTarget` 枚举与 `ReaderOnboardingStep` 映射。
* `OnboardingTargetPreferenceKey.reduce` 目前用面积取大者,这是 `.aiSettings` 被吞的直接原因;若保留多处同名 target 需改 reduce 策略或改用不同 target。
* 验证建议:在真机窗口分别 1280×800 与更大尺寸下逐步核对;或临时打印 `targets[step]` 与挖洞 frame 对比(提交前移除调试代码)。
* 注意:上一轮用合成死坐标离屏渲染导致误判"对齐",**本任务验收必须用真实 ContentView 测量路径**。
