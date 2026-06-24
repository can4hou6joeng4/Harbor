// promo-data.jsx — content, geometry, and timeline keyframes (exported to window)

/* ───────────── geometry (canvas + window + panes) ───────────── */
const CANVAS = { w: 1920, h: 1080 };
const WIN = { x: 64, y: 58, w: 1792, h: 964 };          // Reader window rect within canvas
const PANE = { sidebar: 248, list: 372, ai: 372 };
const TOPBAR = 52;

// pane x-ranges in canvas coords (AI closed for reader width)
const GX = {
  sidebar: [WIN.x, WIN.x + PANE.sidebar],
  list:    [WIN.x + PANE.sidebar, WIN.x + PANE.sidebar + PANE.list],
  reader:  [WIN.x + PANE.sidebar + PANE.list, WIN.x + WIN.w],
  ai:      [WIN.x + WIN.w - PANE.ai, WIN.x + WIN.w],
};
const addBtn = { x: WIN.x + PANE.sidebar - 30, y: WIN.y + 26 };   // sidebar "+" center

/* ───────────── timeline (seconds) ───────────── */
const DUR = 37;
const T = {
  brand:   [0.0, 4.2],
  capture: [4.2, 11.5],
  library: [11.5, 15.5],
  read:    [15.5, 24.5],
  ai:      [24.5, 32.5],
  outro:   [32.5, 37.0],
  // capture sub-beats
  cClickAdd: 5.0, cModalIn: [5.0, 5.45], cTypeStart: 5.7, cTypeEnd: 7.2,
  cFetch: 7.5, cFetchIn: [7.55, 8.05], cClickSave: 9.95, cModalOut: [9.95, 10.3],
  cToast: [10.4, 11.5], cNewCard: 10.4,
  // read sub-beats
  rScroll: [16.2, 19.2], rSelIn: [19.4, 19.8], rHl: 20.2,
  rBiToggle: 21.0, rBiIn: [21.05, 22.0], rScroll2: [22.2, 24.2],
  // ai sub-beats
  aPanelIn: [24.5, 25.25], aSumCtx: 25.35, aSum: 25.7, aKey1: 26.2, aKey2: 26.6, aKey3: 27.0, aTags: 27.4,
  aChatTab: 27.9, aUser: 28.3, aTyping: [28.7, 29.5], aBot: 29.5,
  // outro
  veil: [32.5, 33.7], darkFlip: 33.05, brandIn: 33.9,
};

/* ───────────── cover gradient ───────────── */
function coverBg(h) {
  return `radial-gradient(120% 90% at 16% 10%, rgba(255,253,249,.55), transparent 54%),`
       + `linear-gradient(145deg, oklch(0.84 0.045 ${h}), oklch(0.71 0.06 ${(h + 32) % 360}))`;
}

/* ───────────── sidebar data ───────────── */
const SMART = [
  { id: "inbox",   name: "收件箱",  icon: "inbox",   count: 6, sel: true },
  { id: "all",     name: "全部内容", icon: "stack",   count: 38 },
  { id: "unread",  name: "未读",    icon: "dot",     count: 9 },
  { id: "fav",     name: "收藏",    icon: "star",    count: 4 },
  { id: "later",   name: "稍后读",  icon: "clock",   count: 3 },
  { id: "archive", name: "已归档",  icon: "archive", count: 0 },
];
const FEEDS = [
  { id: "f-ruanyf", name: "阮一峰的网络日志", mono: "阮", color: "#e0533d", count: 3 },
  { id: "f-sspai",  name: "少数派",          mono: "派", color: "#d8443a", count: 5 },
  { id: "f-strat",  name: "Stratechery",    mono: "S",  color: "#1b6cff", count: 2 },
];
const FOLDERS = [
  { id: "fo-fe", name: "前端工程", count: 4 },
  { id: "fo-ai", name: "AI / LLM", count: 5 },
  { id: "fo-product", name: "产品思考", count: 3 },
];
const TAGS = [
  { id: "t-ai",   name: "AI",     color: "#7c5cff" },
  { id: "t-deep", name: "深度长文", color: "#ff8a34" },
  { id: "t-eff",  name: "效率",    color: "#30c463" },
];

/* ───────────── list items (the captured one is prepended at runtime) ───────────── */
const CAPTURED = {
  id: "new", kind: "web", source: "wired.com", title: "为什么你的数据,应该住在你自己的设备里",
  excerpt: "一篇关于「本地优先」浪潮的深度报道:当推理与存储回到端侧,隐私与所有权被重新交还给用户。",
  time: "刚刚", unread: true, fav: false, hasCover: true, hue: 36, readingTime: 7,
  tags: ["t-deep"],
};
const ITEMS = [
  {
    id: "a1", kind: "web", source: "Ink & Switch", title: "Local-First Software:你拥有自己的数据",
    excerpt: "云端应用让协作变得轻松,代价却是你不再真正拥有数据。本地优先,是把所有权还给用户的一种尝试。",
    time: "上午 9:24", unread: false, fav: true, hasCover: true, hue: 255, readingTime: 11,
    tags: ["t-deep", "t-eff"], progress: 0.42,
  },
  {
    id: "a2", kind: "rss", source: "阮一峰的网络日志", title: "科技爱好者周刊:本地大模型的一年",
    excerpt: "过去一年,在笔记本上跑大模型从奇技淫巧变成了日常。聊聊本地推理、量化与隐私。",
    time: "昨天", unread: true, fav: false, hasCover: true, hue: 28, readingTime: 8, tags: ["t-ai", "t-eff"],
  },
  {
    id: "a3", kind: "x", source: "@karpathy", title: "关于 LLM agent 的一段长推:不要把它当成魔法",
    excerpt: "An agent is just a loop: model proposes, you run it, feed the result back. The hard part is the tools.",
    time: "周一", unread: true, fav: false, hasCover: false, readingTime: 3, tags: ["t-ai"],
  },
  {
    id: "a6", kind: "pdf", source: "附件 · PDF", title: "Attention Is All You Need.pdf",
    excerpt: "Transformer 原始论文。15 页,已提取全文与图表,可被 AI 摘要与问答检索。",
    time: "06/02", unread: false, fav: true, hasCover: false, readingTime: 22, tags: ["t-ai", "t-deep"], progress: 0.65,
  },
  {
    id: "a10", kind: "rss", source: "少数派", title: "我的 macOS 效率工作流:用快捷键串起一切",
    excerpt: "从 Raycast 到自定义快捷键,一篇关于如何让 Mac 听话的实操指南。",
    time: "06/03", unread: true, fav: false, hasCover: true, hue: 162, readingTime: 6, tags: ["t-eff"],
  },
];

/* ───────────── the hero article (a1) — full reading content ───────────── */
const ARTICLE = {
  source: "Ink & Switch", author: "Martin Kleppmann 等", time: "上午 9:24", readingTime: 11,
  kind: "web", hue: 255,
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

/* ───────────── AI panel content ───────────── */
const SUMMARY = {
  text: "“本地优先”主张把数据的主副本存在用户设备上,网络只作增强而非前提,以此重新赋予用户对数据的所有权与长期可用性。",
  keys: [
    "数据主副本存在本地设备,而非厂商服务器",
    "网络是增强项,离线是默认能力",
    "本地优先 ≈ 即时响应 + 后台同步",
  ],
  tags: ["本地优先", "CRDT", "数据所有权"],
};
const CHAT = {
  question: "用三句话总结这篇文章",
  answer: ["1. 本地优先把数据主副本放回你的设备,网络只作增强。",
           "2. 它在保留云端协作体验的同时,交还了所有权与离线能力。",
           "3. 衡量标准是即时、可离线、且十年后仍能打开。"],
  cite: "Ink & Switch · Local-First",
  suggest: ["和我收藏的其他文章有何异同?", "把要点整理成一条微博", "解释文中的 CRDT"],
};
const AI_TABS = [
  { id: "summary",   name: "摘要", icon: "doc" },
  { id: "translate", name: "翻译", icon: "translate" },
  { id: "chat",      name: "对话", icon: "chat" },
  { id: "remix",     name: "二创", icon: "wand" },
];

/* ───────────── captions (lower-third) ───────────── */
const CAPTIONS = [
  { start: 4.7,  end: 11.0, text: "一键收藏", sub: "网页 · RSS · PDF · Markdown" },
  { start: 11.9, end: 15.2, text: "你的资料库", sub: "三栏 · 一览无余" },
  { start: 16.1, end: 20.5, text: "沉浸阅读", sub: "划词高亮 · 记住进度" },
  { start: 20.8, end: 24.2, text: "双语对照", sub: "中英逐段对照" },
  { start: 25.3, end: 27.6, text: "AI 摘要", sub: "一句话看懂全文" },
  { start: 27.9, end: 32.1, text: "AI 对话 · 翻译 · 二创", sub: "围绕你读的内容追问" },
];

Object.assign(window, {
  CANVAS, WIN, PANE, TOPBAR, GX, addBtn, DUR, T,
  coverBg, SMART, FEEDS, FOLDERS, TAGS, ITEMS, CAPTURED, ARTICLE,
  SUMMARY, CHAT, AI_TABS, CAPTIONS,
});
