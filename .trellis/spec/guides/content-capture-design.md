# 内容采集层设计指南(Content Capture Design Guide)

> **读者**:接下来实现内容采集层的 AI 开发者(Codex)。
> **地位**:与 `persistence-design.md` 同级的**约束性设计决定**。冲突时先在 task `info.md` 记录再提替代方案,不要静默偏离。
> **背景**:持久化层已交付。当前「添加内容」的抓取按钮和 RSS 订阅都是**模拟**(`AddModal` 点「抓取」只是造假数据,`feed.url` 列全 NULL)。本层让「采集」和「订阅」变真。

---

## 1. 范围决定(MVP 边界,已定)

**做**:① URL 采集(抓网页 → 提取干净正文 + 封面);② RSS/Atom 订阅同步;③ 本地附件导入(PDF/图片,PDF 提取全文)。

**明确推迟,本里程碑禁止触碰**:X / 微博 / YouTube 订阅。原因:三者都没有稳定的免费公开 API,抓取方案(逆向接口/无头浏览器)脆弱且维护成本高,值得单独立项评估,不许混进本层"顺手做"。UI 里这三类平台保留,数据继续走种子。

---

## 2. 技术选型(已定,勿重新发明)

| 用途 | 选型 | 理由 / 否决项 |
|---|---|---|
| HTML 解析与清洗 | **[SwiftSoup](https://github.com/scinfu/SwiftSoup)**(SPM) | 成熟、纯 Swift、可单测。否决 WKWebView + Readability.js:需要离屏 WebView 跑主线程、无法纯单测;但架构上为它**留接口**(见 §3 的 `ContentExtractor` 协议),将来对付 JS 渲染页面时可加为 fallback。否决引入 JS 引擎跑 Readability.js:JSC 无 DOM,行不通 |
| RSS/Atom 解析 | **[FeedKit](https://github.com/nmdias/FeedKit)**(SPM) | RSS/Atom/JSON Feed 全支持;用 `FeedParser(data:)` 从我们自己的 HTTP 层喂数据,**不要**用它的 URL 接口(网络必须收口在 HTTPClient) |
| PDF 文本提取 | **PDFKit**(系统框架) | 原生,零依赖 |
| 语言检测 | **NaturalLanguage** 的 `NLLanguageRecognizer` | 原生;映射到现有 `language: "zh"/"en"`,其他语言落 "en" |

依赖加在 **ReaderCore**。UI target 不直接依赖 SwiftSoup/FeedKit。

---

## 3. 架构

```
ReaderCore/Capture/
  HTTPClient.swift        // 协议 + URLSession 实现;全部网络的唯一出口
  ContentExtractor.swift  // 协议 + SwiftSoupExtractor 实现
  CaptureService.swift    // URL → fetch → extract → ReaderItem → repository.saveItem
  FeedSyncService.swift   // 订阅同步:逐 feed 拉取 → 去重 → 入库
  AttachmentImporter.swift// 文件拷贝进 Attachments/ + PDF 文本提取
```

**铁律**:
- 所有网络经 `HTTPClient` 协议(`func fetch(_ request: CaptureRequest) async throws -> CaptureResponse`),测试注入 mock。**测试禁止碰真实网络**。
- `CaptureService`/`FeedSyncService` 不依赖 GRDB,只依赖 `ReaderRepository` 协议——与持久化层同样的隔离纪律。
- View 层不直接调 Capture 服务,一律经 `ReaderStore`。

**HTTPClient 实现规范**:UA 设 `ReaderMacApp/1.0 (Macintosh; macOS)`;超时 15s;响应体上限 5MB(超限截断报错);重定向上限 5 次;编码探测顺序 = HTTP header `textEncodingName` → HTML `<meta charset>` → UTF-8 兜底。

---

## 4. Schema v2(新迁移,不改 v1)

```sql
-- registerMigration("v2")
ALTER TABLE item ADD COLUMN url TEXT;          -- 原文链接
ALTER TABLE item ADD COLUMN guid TEXT;         -- RSS 条目唯一标识(去重用)
ALTER TABLE item ADD COLUMN cover_path TEXT;   -- 已下载封面的相对路径(Attachments/ 下)
ALTER TABLE feed ADD COLUMN last_fetched_at REAL;
ALTER TABLE feed ADD COLUMN etag TEXT;
ALTER TABLE feed ADD COLUMN last_modified TEXT;
CREATE UNIQUE INDEX item_feed_guid_idx ON item(feed_id, guid) WHERE guid IS NOT NULL;
```

`ReaderItem` 模型加 `url: String?`、`guid: String?`、`coverPath: String?`(连带 `LibrarySnapshot`/repository 读写路径、`InMemoryRepository` 同步更新)。`Feed` 模型加 `url`,订阅管理 UI 的「添加订阅」走真数据。

---

## 5. URL 采集管线(Task C 核心)

`fetch → 清洗 → 提取 → 映射 → 语言 → 封面`,每步规范:

1. **清洗**(SwiftSoup):移除 `script/style/nav/header/footer/aside/form/iframe`、广告类 class/id(`ad|banner|promo|comment|sidebar|related` 正则)。
2. **正文定位**(启发式,按序):`<article>` → `[role=main]`/`<main>` → 全文档**文本密度评分**(候选块得分 = 文本长度 × 段落数 ÷ (1+链接文字占比);取最高分块)。提取失败(正文 < 200 字符)→ 明确报错给 UI(toast「未能提取正文」),**不许静默存空文章**。
3. **映射到 `[ContentBlock]`**:`<p>` → paragraph(首段 → lead);`<h2-h4>` → heading;`<blockquote>` → quote;`<img>`(正文内,有 alt 或宽度暗示的)→ image block,`caption` 取 `alt`/`figcaption`。translation 一律留空。
4. **元数据**:标题 = `og:title` → `<title>`;摘要 = `og:description` → 正文前 100 字;作者 = `meta[name=author]` → 域名;`publishedAt` = `article:published_time` → 当前时间。
5. **语言**:对正文前 500 字符跑 `NLLanguageRecognizer`。
6. **封面**:`og:image` 存在 → 经 HTTPClient 下载(同样限 5MB)→ 存 `Attachments/<uuid>.<ext>` → 写 `cover_path`;失败不阻塞保存(降级为现有 hue 渐变)。UI:列表缩略图与阅读区 hero 在 `coverPath` 非空时渲染本地图片(`NSImage(contentsOf:)`),否则保持 `CoverGradient` 现状。
7. **AddModal 接线**:「抓取」按钮变真——抓取中给 loading 态,成功显示真实预览(标题/域名/摘要),「保存到本地」落库;失败 toast 明确原因(超时/非 HTML/提取失败)。

**正文内图片不下载**(只下封面)。全文离线图片留到后续任务,本层先保证文字完整。

---

## 6. RSS 同步(Task D 核心)

- **条目身份**:`guid` = feed entry 的 `guid`/`id` → 退化用 `link` → 再退化用 `hash(title + pubDate)`。靠 §4 的唯一索引去重,重复条目跳过(**不**更新已有条目,避免覆盖用户的高亮/进度)。
- **条件请求**:发送 `If-None-Match`(etag)/`If-Modified-Since`(last_modified);304 → 跳过解析,只更新 `last_fetched_at`。
- **并发**:`TaskGroup` 同步所有启用的 feed,并发上限 4;**单 feed 失败不影响其他**,失败记入该 feed(UI 订阅管理里显示「上次同步失败」即可,不弹窗轰炸)。
- **RSS 条目正文**:`content:encoded` → `description`,经同一套 SwiftSoup 清洗映射成 blocks;正文过短(< 200 字符)标记该条目为「摘要型」,阅读区底部给「抓取全文」按钮走 Task C 管线补全。
- **刷新策略**:① 订阅管理/侧栏手动刷新按钮;② App 启动时若 `min(last_fetched_at)` 距今 > 1 小时自动同步;③ 运行期 `Timer` 每小时一轮。同步中侧栏给轻量进度指示(转圈即可)。
- **新条目落库**:`isUnread = true`,`feedID` 归属正确,`folderID` 留空(用户自己整理)。

---

## 7. 附件导入(Task E,小)

- 入口:AddModal「附件」tab 的拖拽区 + 点击选择(`NSOpenPanel`,允许 pdf/png/jpeg/heic/mp4/mov)。
- 文件**拷贝**进 `Attachments/<uuid>.<ext>`(不引用原位置),写 `attachment_path`。
- PDF:`PDFDocument` 逐页提取文本 → 每页一个 paragraph block(空页跳过);`readingTime` 按 400 字/分钟估算;首页 `thumbnail` 渲染存为封面。
- 图片:文件本身即封面(`cover_path` 指向它),正文给一个 image block + 可编辑备注。
- 视频:只存文件 + 时长(`AVURLAsset.duration`),不做转码/字幕。

---

## 8. 顺手修(上轮验收遗留,并入 Task C)

1. **入口静默降级**:`ReaderMacApp.init` 里 GRDB 初始化失败 fallback 到 InMemory 时,必须在首窗口给 alert 告知「本地数据库不可用,本次会话数据不会保存」,并把 error 打到 log。
2. **FTS 短语查询**:`ftsQuery` 改为整体短语(一对引号包住全部空格分隔的字符),让「本地优先」只命中连续出现;英文多词维持 AND 也可,中文必须短语化。改完补一个测试:搜「本地优先」不命中四字分散的文档。

---

## 9. 任务拆分(三个 Trellis task,顺序执行)

**Task C「URL 采集」**:HTTPClient + SwiftSoupExtractor + CaptureService + 迁移 v2 + AddModal 接线 + 封面下载渲染 + §8 两项。验收:粘贴真实文章 URL 能抓取、预览、保存、重启后还在;提取失败有明确反馈;fixture 测试覆盖提取管线(≥3 个真实网页快照:中文博客/英文长文/带 og:image 的新闻页)+ 迁移 v2 测试;`swift build`/`swift test`/`--verify` 全绿。

**Task D「RSS 同步」**:FeedSyncService + 条件请求 + 去重 + 刷新策略 + 订阅管理接线。验收:添加真实 RSS URL(如 `https://www.ruanyifeng.com/blog/atom.xml`)→ 同步出条目 → 重启还在 → 再次同步不重复;fixture 测试覆盖 RSS/Atom 解析、guid 退化链、304 路径、单 feed 失败隔离。

**Task E「附件导入」**:AttachmentImporter + AddModal 附件 tab 接线。验收:拖入 PDF → 全文可读可搜(FTS 能命中 PDF 正文)→ 重启还在;fixture 用仓库内生成的小 PDF。

每个 task 各自 `task.py create`,PRD 引用本文档章节,不复述规则。

---

## 10. 明确不做(Out of Scope)

- X / 微博 / YouTube 真实抓取(单独里程碑)
- 正文内图片离线化、网页快照存档
- JS 渲染页面(SPA)的提取(架构留了 `ContentExtractor` 协议位)
- 真实 AI 接入;OPML 导入导出;推送通知

---

## 11. 自查清单(提交前)

- [ ] 测试零真实网络(grep 测试代码无 `URLSession`,全部走 mock HTTPClient + fixture)
- [ ] UI/Store 层无 `import SwiftSoup/FeedKit`
- [ ] 迁移 v2 只追加,v1 未被改动(`git diff` 验证 Migrations.swift 旧块无变化)
- [ ] 失败路径全部有用户可见反馈(超时/非 HTML/提取失败/feed 失败)
- [ ] 主线程无网络/解析(提取跑在后台,UI 只收结果)
- [ ] 杀进程重开:抓取的文章、RSS 条目、附件全部存活
- [ ] `swift build` && `swift test` && `./script/build_and_run.sh --verify` 全绿
