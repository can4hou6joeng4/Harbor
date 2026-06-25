// promo-data.jsx — full app content, geometry, and timeline keyframes (exported to window)

/* ───────────── geometry (canvas + window + panes) ───────────── */
const CANVAS = { w: 1920, h: 1080 };
const WIN = { x: 64, y: 58, w: 1792, h: 964 };
const PANE = { sidebar: 248, list: 372, ai: 372 };
const TOPBAR = 52;
const GX = {
  sidebar: [WIN.x, WIN.x + PANE.sidebar],
  list:    [WIN.x + PANE.sidebar, WIN.x + PANE.sidebar + PANE.list],
  reader:  [WIN.x + PANE.sidebar + PANE.list, WIN.x + WIN.w],
  ai:      [WIN.x + WIN.w - PANE.ai, WIN.x + WIN.w],
};
const addBtn = { x: WIN.x + PANE.sidebar - 30, y: WIN.y + 26 };

/* ───────────── timeline (seconds) ───────────── */
const DUR = 55;
const T = {
  brand:    [0.0, 4.0],
  overview: [4.0, 9.5],
  capture:  [9.5, 19.0],
  library:  [19.0, 25.0],
  read:     [25.0, 35.0],
  ai:       [35.0, 48.0],
  outro:    [48.0, 55.0],

  // capture sub-beats
  cClickAdd: 10.3, cModalIn: [10.3, 10.75], cTypeStart: 11.0, cTypeEnd: 12.6,
  cFetch: 12.95, cFetchIn: [13.0, 13.5], cClickSave: 14.6, cModalOut: [14.6, 14.95],
  cToast: [15.0, 16.2], cNewCard: 15.0,
  // subscriptions manager beat
  subsIn: [16.5, 16.95], subsOut: [18.4, 18.75],

  // library + command palette
  palIn: [21.7, 22.1], palType: [22.3, 23.2], palOut: [24.4, 24.75],

  // read sub-beats
  rScroll: [25.6, 28.0], rSelIn: [28.2, 28.6], rHl: 29.0,
  typoIn: [30.0, 30.4], typoSerif: 30.7, typoOut: [31.5, 31.8],
  rBiToggle: 32.2, rBiIn: [32.25, 33.1], rScroll2: [33.4, 34.7],

  // ai sub-beats
  aPanelIn: [35.0, 35.7], aSumCtx: 35.8, aSum: 36.1, aKey1: 36.5, aKey2: 36.9, aKey3: 37.3, aTags: 37.7,
  aTransTab: 38.4, aChatTab: 40.6, aUser: 41.0, aTyping: [41.4, 42.2], aBot: 42.2,
  aRemixTab: 44.0, aRemixPick: 44.6, aRemixOut: [45.1, 45.8],

  // outro
  veil: [48.3, 49.6], darkFlip: 48.95, brandIn: 50.6,
};

/* ───────────── cover gradient ───────────── */
function coverBg(h) {
  return `radial-gradient(120% 90% at 16% 10%, rgba(255,253,249,.55), transparent 54%),`
       + `linear-gradient(145deg, oklch(0.84 0.045 ${h}), oklch(0.71 0.06 ${(h + 32) % 360}))`;
}

/* ───────────── sidebar: smart views ───────────── */
const SMART = [
  { id: "inbox",   name: "收件箱",  icon: "inbox",   count: 6, sel: true },
  { id: "all",     name: "全部内容", icon: "stack",   count: 38 },
  { id: "unread",  name: "未读",    icon: "dot",     count: 9 },
  { id: "fav",     name: "收藏",    icon: "star",    count: 4 },
  { id: "later",   name: "稍后读",  icon: "clock",   count: 3 },
  { id: "archive", name: "已归档",  icon: "archive", count: 0 },
];

/* ───────────── subscriptions tree (4 platforms) ───────────── */
const PLATFORMS = [
  { id: "p-rss", name: "RSS", icon: "rss", open: true, feeds: [
    { id: "f-ruanyf", name: "阮一峰的网络日志", mono: "阮", color: "#e0533d", count: 3 },
    { id: "f-sspai",  name: "少数派",          mono: "派", color: "#d8443a", count: 5 },
    { id: "f-strat",  name: "Stratechery",    mono: "S",  color: "#1b6cff", count: 2 },
  ]},
  { id: "p-x", name: "X", icon: "x", open: false, feeds: [
    { id: "f-karpathy", name: "@karpathy", mono: "K", color: "#111", count: 1 },
    { id: "f-rauchg",   name: "@rauchg",   mono: "R", color: "#111", count: 1 },
  ]},
  { id: "p-weibo", name: "微博", icon: "weibo", open: false, feeds: [
    { id: "f-lanxi", name: "@阑夕", mono: "阑", color: "#e6162d", count: 2 },
  ]},
  { id: "p-yt", name: "YouTube", icon: "youtube", open: false, feeds: [
    { id: "f-veritasium", name: "Veritasium", mono: "V", color: "#cf2b2b", count: 1 },
    { id: "f-rauno",      name: "Rauno Freiberg", mono: "R", color: "#cf2b2b", count: 1 },
  ]},
];

/* ───────────── folder tree ───────────── */
const FOLDERS = [
  { id: "fo-tech", name: "技术", open: true, children: [
    { id: "fo-fe", name: "前端工程", count: 4 },
    { id: "fo-ai", name: "AI / LLM", count: 5 },
  ]},
  { id: "fo-product", name: "产品思考", count: 3 },
  { id: "fo-design",  name: "设计灵感", count: 2 },
  { id: "fo-life",    name: "生活方式", count: 1 },
];

/* ───────────── tags (6) ───────────── */
const TAGS = [
  { id: "t-ai",    name: "AI",       color: "#7c5cff" },
  { id: "t-fe",    name: "前端",      color: "#0a84ff" },
  { id: "t-design",name: "设计",      color: "#ff5c93" },
  { id: "t-eff",   name: "效率",      color: "#30c463" },
  { id: "t-deep",  name: "深度长文",   color: "#ff8a34" },
  { id: "t-idea",  name: "灵感",      color: "#13b8c4" },
];

/* ───────────── list items (12, all types) — captured one prepends at runtime ───────────── */
const CAPTURED = {
  id: "new", kind: "web", source: "wired.com", title: "为什么你的数据,应该住在你自己的设备里",
  excerpt: "一篇关于「本地优先」浪潮的深度报道:当推理与存储回到端侧,隐私与所有权被重新交还给用户。",
  time: "刚刚", unread: true, fav: false, hasCover: true, hue: 36, readingTime: 7, tags: ["t-deep"],
};
const ITEMS = [
  { id: "a1", kind: "web", source: "Ink & Switch", title: "Local-First Software:你拥有自己的数据",
    excerpt: "云端应用让协作变得轻松,代价却是你不再真正拥有数据。本地优先,是把所有权还给用户的一种尝试。",
    time: "上午 9:24", unread: false, fav: true, hasCover: true, hue: 255, readingTime: 11, tags: ["t-deep", "t-eff"], progress: 0.42 },
  { id: "a2", kind: "rss", source: "阮一峰的网络日志", title: "科技爱好者周刊:本地大模型的一年",
    excerpt: "过去一年,在笔记本上跑大模型从奇技淫巧变成了日常。聊聊本地推理、量化与隐私。",
    time: "昨天", unread: true, fav: false, hasCover: true, hue: 28, readingTime: 8, tags: ["t-ai", "t-eff"] },
  { id: "a3", kind: "x", source: "@karpathy", title: "关于 LLM agent 的一段长推:不要把它当成魔法",
    excerpt: "An agent is just a loop: model proposes, you run it, feed the result back. The hard part is the tools.",
    time: "周一", unread: true, fav: false, hasCover: false, readingTime: 3, tags: ["t-ai"] },
  { id: "a4", kind: "youtube", source: "Veritasium", title: "Dijkstra 最短路径算法,到底在做什么?",
    excerpt: "一个关于贪心、优先队列和地图导航的可视化讲解。28 分钟看懂图论里最优雅的算法之一。",
    time: "周日", unread: false, fav: true, hasCover: true, hue: 8, duration: "28:14", tags: ["t-fe"], progress: 0.18 },
  { id: "a6", kind: "pdf", source: "附件 · PDF", title: "Attention Is All You Need.pdf",
    excerpt: "Transformer 原始论文。15 页,已提取全文与图表,可被 AI 摘要与问答检索。",
    time: "06/02", unread: false, fav: true, hasCover: false, readingTime: 22, tags: ["t-ai", "t-deep"], progress: 0.65 },
  { id: "a7", kind: "markdown", source: "我的笔记", title: "周回顾 · 2026-W23",
    excerpt: "本周读完 3 篇长文,关于本地优先和 agent。下周想动手做一个本地阅读器的原型……",
    time: "06/07", unread: false, fav: false, hasCover: false, readingTime: 1, tags: ["t-eff"] },
  { id: "a8", kind: "rss", source: "Stratechery", title: "The AI Hardware Question",
    excerpt: "Why the most interesting AI story of the year might not be a model at all, but where inference happens.",
    time: "06/06", unread: true, fav: false, hasCover: true, hue: 220, readingTime: 9, tags: ["t-ai", "t-deep"] },
  { id: "a9", kind: "image", source: "附件 · 图片", title: "设计灵感:Things 3 的空状态",
    excerpt: "截了一张 Things 3 的空状态截图,留白和插画都很克制。存进「设计灵感」。",
    time: "06/05", unread: false, fav: false, hasCover: true, hue: 48, readingTime: 1, tags: ["t-design", "t-idea"] },
  { id: "a10", kind: "rss", source: "少数派", title: "我的 macOS 效率工作流:用快捷键串起一切",
    excerpt: "从 Raycast 到自定义快捷键,一篇关于如何让 Mac 听话的实操指南。",
    time: "06/03", unread: true, fav: false, hasCover: true, hue: 162, readingTime: 6, tags: ["t-eff", "t-fe"] },
];

/* ───────────── hero article (a1) — full reading content ───────────── */
const ARTICLE = {
  source: "Ink & Switch", author: "Martin Kleppmann 等", time: "上午 9:24", readingTime: 11, kind: "web", hue: 255,
  title: "Local-First Software:你拥有自己的数据",
  blocks: [
    { t: "lead", lang: "en",
      text: "Cloud apps like Google Docs and Trello are popular because they enable real-time collaboration. But the price is steep: you no longer truly own that data.",
      tr: "像 Google Docs、Trello 这样的云端应用之所以流行,是因为它们支持实时协作。但代价高昂:你不再真正拥有这些数据。" },
    { t: "p", lang: "en",
      text: "If the company behind the service shuts it down, your documents can vanish overnight. The software you rely on every day is, in the end, borrowed.",
      tr: "一旦背后的公司关停服务,你的文档就可能在一夜之间消失。你每天依赖的软件,说到底只是借来的。",
      hl: "The software you rely on every day is, in the end, borrowed." },
    { t: "h2", lang: "en", text: "Seven ideals for local-first software", tr: "本地优先软件的七个理想" },
    { t: "p", lang: "en",
      text: "We call an application “local-first” when it keeps the primary copy of your data on your own device, while still supporting seamless collaboration. The network becomes an enhancement, not a requirement.",
      tr: "当一个应用把数据的主副本保存在你自己的设备上,同时仍能提供无缝协作时,我们称它为“本地优先”。网络成了一种增强,而不是必需品。" },
    { t: "quote", lang: "en",
      text: "The data is yours, and the software is merely a lens through which you view and edit it.",
      tr: "数据是你的,软件只是你查看和编辑它的一面镜片。" },
    { t: "p", lang: "en",
      text: "Offline by default. A flaky connection on a train should never stop you from reading or writing. And because the bytes live with you, the work you make today should still open in a decade.",
      tr: "默认离线可用。火车上时断时续的信号,不该阻止你阅读或书写。而且因为数据就在你身边,你今天创作的东西,十年后也应当还能打开。" },
  ],
};

/* ───────────── AI content ───────────── */
const SUMMARY = {
  text: "“本地优先”主张把数据的主副本存在用户设备上,网络只作增强而非前提,以此重新赋予用户对数据的所有权与长期可用性。",
  keys: ["数据主副本存在本地设备,而非厂商服务器", "网络是增强项,离线是默认能力", "本地优先 ≈ 即时响应 + 后台同步"],
  tags: ["本地优先", "CRDT", "数据所有权"],
};
const TRANSLATE = [
  "像 Google Docs、Trello 这样的云端应用之所以流行,是因为它们支持实时协作。但代价高昂:你不再真正拥有这些数据。",
  "一旦背后的公司关停服务,你的文档就可能在一夜之间消失。你每天依赖的软件,说到底只是借来的。",
  "本地优先软件的七个理想",
  "当一个应用把数据的主副本保存在你自己的设备上,同时仍能提供无缝协作时,我们称它为“本地优先”。",
];
const CHAT = {
  question: "用三句话总结这篇文章",
  answer: ["1. 本地优先把数据主副本放回你的设备,网络只作增强。",
           "2. 它在保留云端协作体验的同时,交还了所有权与离线能力。",
           "3. 衡量标准是即时、可离线、且十年后仍能打开。"],
  cite: "Ink & Switch · Local-First",
  suggest: ["和我收藏的其他文章有何异同?", "把要点整理成一条微博", "解释文中的 CRDT"],
};
const REMIX = [
  { id: "rx-note",  icon: "doc",      title: "整理成读书笔记",   desc: "提炼要点 + 我的高亮,生成 Markdown 笔记" },
  { id: "rx-thread",icon: "x",        title: "改写成 X 推文串",   desc: "把长文压缩成 5 条推文的 thread" },
  { id: "rx-weekly",icon: "calendar", title: "汇入本周周报",     desc: "合并本周读过的内容,生成回顾草稿" },
  { id: "rx-cross", icon: "sparkles", title: "跨文章二次创作",   desc: "选取多篇内容,生成一篇综述短文" },
];
const REMIX_OUT = "# Local-First Software · 读书笔记\n\n## 要点\n- 数据主副本存在本地设备,而非厂商服务器\n- 网络是增强项,离线是默认能力\n- 本地优先 ≈ 即时响应 + 后台同步\n\n## 我的高亮\n> The software you rely on every day is, in the end, borrowed.";
const AI_TABS = [
  { id: "summary",   name: "摘要", icon: "doc" },
  { id: "translate", name: "翻译", icon: "translate" },
  { id: "chat",      name: "对话", icon: "chat" },
  { id: "remix",     name: "二创", icon: "wand" },
];

/* ───────────── command palette ───────────── */
const PALETTE = {
  query: "local",
  commands: [
    { icon: "plus",    title: "添加内容", sub: "粘贴链接 / 导入文件", kbd: "⌘N" },
    { icon: "search",  title: "全文搜索", sub: "搜索标题、正文、标签", kbd: "⌘F" },
    { icon: "rss",     title: "管理订阅源", sub: "RSS · X · 微博 · YouTube" },
  ],
  items: [
    { kind: "web", title: "Local-First Software:你拥有自己的数据", sub: "Ink & Switch · 11 分钟" },
    { kind: "rss", title: "The AI Hardware Question", sub: "Stratechery · 9 分钟" },
    { kind: "x",   title: "Local-first is the next big shift", sub: "@rauchg · 2 分钟" },
  ],
};

/* ───────────── captions (lower-third) ───────────── */
const CAPTIONS = [
  { start: 4.7,  end: 9.0,  text: "完整的本地阅读空间", sub: "三栏 · 多源 · 数据全在本地" },
  { start: 10.2, end: 18.6, text: "一键收藏 · 多源聚合", sub: "网页 · RSS · X · 微博 · YouTube · PDF" },
  { start: 19.4, end: 24.6, text: "资料库 · ⌘K 速达", sub: "标签 · 目录 · 全文搜索" },
  { start: 25.5, end: 31.3, text: "沉浸阅读", sub: "划词高亮 · 排版调节 · 记住进度" },
  { start: 31.6, end: 34.8, text: "双语对照", sub: "中英逐段对照" },
  { start: 35.6, end: 40.3, text: "AI 摘要与翻译", sub: "一句话看懂 · 逐段翻译" },
  { start: 40.5, end: 47.6, text: "AI 对话 · 二次创作", sub: "围绕你读的内容追问、改写" },
];

Object.assign(window, {
  CANVAS, WIN, PANE, TOPBAR, GX, addBtn, DUR, T,
  coverBg, SMART, PLATFORMS, FOLDERS, TAGS, ITEMS, CAPTURED, ARTICLE,
  SUMMARY, TRANSLATE, CHAT, REMIX, REMIX_OUT, AI_TABS, PALETTE, CAPTIONS,
});
