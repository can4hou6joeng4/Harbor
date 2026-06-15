# 本地持久化设计指南(Persistence Design Guide)

> **读者**:接下来实现持久化层的 AI 开发者(Codex)。
> **地位**:本文档是持久化层的**约束性设计决定**,不是建议。如实现中发现与现实冲突,先在 task 的 `info.md` 里记录冲突再提出替代方案,不要静默偏离。
> **背景**:产品核心承诺是「数据都在本地」。当前 App 所有状态都在内存(`SampleLibrary` 种子 + `ReaderStore` @Published),退出即丢,这是目前最大的功能缺口。

---

## 1. 技术选型(已定,勿重新发明)

**SQLite,通过 [GRDB.swift](https://github.com/groue/GRDB.swift) 访问,全文搜索用 FTS5。**

| 候选 | 结论 | 原因 |
|---|---|---|
| **GRDB + SQLite** | ✅ 采用 | 支持 macOS 13(无需升平台);FTS5 全文搜索是阅读器刚需;迁移机制(`DatabaseMigrator`)成熟;`ValueObservation` 可做响应式;本地优先应用的事实标准 |
| SwiftData | ❌ 否 | 要求 macOS 14(`Package.swift` 锁 13);无 FTS;迁移控制弱 |
| JSON 文件 | ❌ 否 | 上千篇文章 + 搜索 + 标签过滤场景下注定要换 SQLite,先用 JSON 等于自找一次返工 |

依赖添加方式:`Package.swift` 中给 **ReaderCore** target 加 `.package(url: "https://github.com/groue/GRDB.swift.git", from: "6.0.0")`。UI target 不直接依赖 GRDB。

---

## 2. 架构:Repository 协议隔离

**ReaderStore 不许直接 import GRDB。** 所有读写经过协议:

```
ReaderCore/
  Persistence/
    ReaderRepository.swift      // 协议(async 接口)
    GRDBRepository.swift        // SQLite 实现(唯一 import GRDB 的地方)
    InMemoryRepository.swift    // 测试/Preview 用,语义与 GRDB 实现一致
    Migrations.swift            // 全部 schema 迁移
  ReaderStore.swift             // 注入 ReaderRepository,仍是 @MainActor ObservableObject
```

协议形态(签名可微调,职责不可少):

```swift
public protocol ReaderRepository: Sendable {
    func loadLibrary() async throws -> LibrarySnapshot   // items+tags+folders+feeds 一次性快照
    func saveItem(_ item: ReaderItem) async throws        // upsert(含 body/highlights)
    func deleteItem(id: String) async throws
    func setItemFlags(id: String, isUnread: Bool?, isFavorite: Bool?) async throws
    func saveHighlights(itemID: String, _ highlights: [Highlight]) async throws
    func saveReadingState(itemID: String, progress: Double, offset: Double) async throws
    func search(_ query: String) async throws -> [String] // FTS5,返回 item id 列表
}
```

数据流向:**写操作 = 先改内存(@Published,UI 即时响应)→ 再 `Task` 异步落库;读 = 启动时 `loadLibrary()` 一次性进内存。** 本应用数据量(万级条目)全量驻留内存没有问题,不要做按需分页——那是以后的优化,v1 禁止引入这种复杂度。`ValueObservation` 响应式同步**不做**(单窗口无外部写者,属于过度设计)。

---

## 3. 存放位置

```
~/Library/Application Support/ReaderMacApp/
  reader.sqlite            // 数据库(WAL 模式)
  Attachments/<uuid>.<ext> // PDF/图片/视频原文件,DB 只存相对路径
```

用 `FileManager.url(for: .applicationSupportDirectory, ...)` 拼接,首次启动建目录。**禁止硬编码绝对路径。** 单元测试一律用临时目录或内存库(`DatabaseQueue()`),不许碰真实用户目录。

---

## 4. Schema v1(DDL 草案)

```sql
CREATE TABLE item (
  id TEXT PRIMARY KEY,            -- UUID 字符串(见 §5)
  kind TEXT NOT NULL,             -- ReaderKind.rawValue
  source TEXT NOT NULL,
  feed_id TEXT REFERENCES feed(id) ON DELETE SET NULL,
  author TEXT NOT NULL DEFAULT '',
  title TEXT NOT NULL,
  excerpt TEXT NOT NULL DEFAULT '',
  published_at REAL NOT NULL,     -- Date.timeIntervalSince1970(见 §5)
  reading_time INTEGER,
  duration TEXT,
  language TEXT NOT NULL DEFAULT 'zh',
  folder_id TEXT REFERENCES folder(id) ON DELETE SET NULL,
  is_favorite INTEGER NOT NULL DEFAULT 0,
  is_unread INTEGER NOT NULL DEFAULT 1,
  progress REAL NOT NULL DEFAULT 0,
  reading_offset REAL NOT NULL DEFAULT 0,
  hue REAL NOT NULL DEFAULT 0,
  has_cover INTEGER NOT NULL DEFAULT 0,
  attachment_path TEXT,           -- 相对 Attachments/ 的路径
  body_json TEXT NOT NULL,        -- [ContentBlock] 的 JSON(见下方说明)
  summary_json TEXT               -- ReaderSummary 的 JSON
);

CREATE TABLE highlight (
  id TEXT PRIMARY KEY,
  item_id TEXT NOT NULL REFERENCES item(id) ON DELETE CASCADE,
  quote TEXT NOT NULL,
  note TEXT NOT NULL DEFAULT '',
  created_at REAL NOT NULL
);

CREATE TABLE tag (
  id TEXT PRIMARY KEY, name TEXT NOT NULL, color_hex TEXT NOT NULL
);
CREATE TABLE item_tag (
  item_id TEXT NOT NULL REFERENCES item(id) ON DELETE CASCADE,
  tag_id  TEXT NOT NULL REFERENCES tag(id)  ON DELETE CASCADE,
  PRIMARY KEY (item_id, tag_id)
);

CREATE TABLE folder (
  id TEXT PRIMARY KEY, name TEXT NOT NULL,
  parent_id TEXT REFERENCES folder(id) ON DELETE CASCADE,
  sort_order INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE feed (
  id TEXT PRIMARY KEY, platform TEXT NOT NULL,   -- 'rss'|'x'|'weibo'|'youtube'
  name TEXT NOT NULL, monogram TEXT NOT NULL, color_hex TEXT NOT NULL,
  is_enabled INTEGER NOT NULL DEFAULT 1, url TEXT
);

-- 全文搜索(external content 模式,触发器同步)
CREATE VIRTUAL TABLE item_fts USING fts5(
  title, excerpt, body_text, content='', tokenize='unicode61'
);
```

**设计取舍说明**:
- `body_json`:正文块永远整篇加载、从不单块查询,所以存 JSON 列,**不要**为 ContentBlock 建表(过度范式化)。但写入时把所有块的纯文本拼接写进 `item_fts.body_text`,FTS 才搜得到正文。
- 中文搜索:`unicode61` 对 CJK 是逐字索引,搜「本地优先」这类连续子串够用;**不要**为此引入自定义分词器。
- `chat` 消息**不持久化**(会话级状态)。`platform` 不单独建表(枚举,随 feed 走)。

---

## 5. 既有模型的必要修整(随本任务一起做,否则将来返工)

1. **ID 改 UUID**:`ReaderStore.addItem` 现在用 `"u\(items.count + 1)"` 生成 id——删除条目后会撞 id。改为 `UUID().uuidString`。种子数据保留 `a1...a12` 字符串 id 没关系(TEXT 主键)。
2. **时间改真实 Date**:`ReaderItem.timestamp: Int`(假数值 100/95/999)和 `time: String`(写死的「昨天」)必须换成 `publishedAt: Date`;列表显示的相对时间改为**派生**(`RelativeDateTimeFormatter`)。持久化假时间戳 = 把占位符变成债。种子数据按当前日期倒推几小时/几天构造 Date。
3. **阅读位置入库**:`readingOffsets` 字典目前刻意只存内存(`testReadingOffsetIsMemoryOnlyAndNonNegative` 测试要同步改),改为经 `saveReadingState` 落库;**写库要节流**(如 0.5s debounce 或 onDisappear 时写),滚动事件不许逐条写库。
4. **偏好不进 DB**:字号/行距/栏宽/衬线/双语/主题这些用 `UserDefaults`(`@AppStorage` 亦可),不属于数据库。

---

## 6. 首次启动种子

启动时若 `item` 表为空 → 把 `SampleLibrary` 全量写入 DB(让用户首次打开仍看到示例内容,也是 dogfood 数据)。`SampleLibrary` 本身保留,继续供 Preview 和 `InMemoryRepository` 使用。

---

## 7. 迁移纪律(红线)

- 所有 schema 通过 `DatabaseMigrator` 注册,v1 即 `migrator.registerMigration("v1") { ... }`。
- **已发布的迁移永不修改**,任何 schema 变更 = 追加新迁移。
- 测试必须包含:空库跑全部迁移成功 + 种子写入后重开库数据完整(模拟重启)。

---

## 8. 建议任务拆分(两个 Trellis task,各自可交付)

**Task A「持久化基座」**:GRDB 依赖 + Schema/迁移 + `ReaderRepository` 三件套 + 种子写入 + 模型修整(§5 的 1/2)。验收:`swift build`/`swift test` 过;新增测试覆盖 迁移、item/highlight/tag round-trip、FTS 中英文搜索、级联删除;**此时 ReaderStore 可以还没接上**。

**Task B「接线 ReaderStore」**:Store 注入 repository;启动 `loadLibrary`;收藏/已读/高亮/新增条目/阅读位置(§5-3,含节流)逐个接写库;偏好迁到 UserDefaults(§5-4);列表搜索接 FTS(保留现有内存过滤作为 fallback 也行,二选一说清楚)。验收:**杀进程重开,新增条目、高亮、笔记、收藏态、阅读位置全部还在**;`./script/build_and_run.sh --verify` 过。

每个 task 用 `python3 ./.trellis/scripts/task.py create ...` 走正常流程,PRD 直接引用本文档章节即可,不必复述 schema。

---

## 9. 明确不做(Out of Scope)

- iCloud/多设备同步、按需分页加载、ValueObservation 响应式管道
- URL/RSS 真实抓取(那是下一个里程碑,但 `feed.url` 列已为它预留)
- 真实 AI 服务接入;chat 历史持久化
- 自定义 FTS 分词器

---

## 10. 自查清单(提交前)

- [ ] ReaderStore/View 层没有 `import GRDB`
- [ ] 主线程无同步 DB I/O(Instruments 或 review 确认写路径全 async)
- [ ] 滚动写库有节流,不是每个 scroll event 一条 UPDATE
- [ ] 测试用临时库,跑完不在用户目录留文件
- [ ] `swift build` && `swift test` && `./script/build_and_run.sh --verify` 全绿
- [ ] 杀进程重开验证过数据存活(写进 task 的手动验证记录)
