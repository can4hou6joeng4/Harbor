// data.jsx — mock content, sources, folders, tags + helpers (exported to window)

// ── smart views ──────────────────────────────────────────────
const SMART = [
  { id: "inbox",   name: "收件箱",  icon: "inbox",   count: 6 },
  { id: "all",     name: "全部内容", icon: "stack",   count: 0 },
  { id: "unread",  name: "未读",    icon: "dot",     count: 9 },
  { id: "fav",     name: "收藏",    icon: "star",    count: 4 },
  { id: "later",   name: "稍后读",  icon: "clock",   count: 3 },
  { id: "archive", name: "已归档",  icon: "archive", count: 0 },
];

// ── tags (with color) ────────────────────────────────────────
const TAGS = [
  { id: "t-ai",    name: "AI",       color: "#7c5cff" },
  { id: "t-fe",    name: "前端",      color: "#0a84ff" },
  { id: "t-design",name: "设计",      color: "#ff5c93" },
  { id: "t-eff",   name: "效率",      color: "#30c463" },
  { id: "t-deep",  name: "深度长文",   color: "#ff8a34" },
  { id: "t-idea",  name: "灵感",      color: "#13b8c4" },
];

// ── subscriptions tree (by platform) ─────────────────────────
const PLATFORMS = [
  { id: "p-rss", name: "RSS", icon: "rss", feeds: [
    { id: "f-ruanyf", name: "阮一峰的网络日志", mono: "阮", color: "#e0533d", count: 3 },
    { id: "f-sspai",  name: "少数派",          mono: "派", color: "#d8443a", count: 5 },
    { id: "f-strat",  name: "Stratechery",    mono: "S",  color: "#1b6cff", count: 2 },
  ]},
  { id: "p-x", name: "X", icon: "x", feeds: [
    { id: "f-karpathy", name: "@karpathy", mono: "K", color: "#111", count: 1 },
    { id: "f-rauchg",   name: "@rauchg",   mono: "R", color: "#111", count: 1 },
  ]},
  { id: "p-weibo", name: "微博", icon: "weibo", feeds: [
    { id: "f-lanxi", name: "@阑夕", mono: "阑", color: "#e6162d", count: 2 },
  ]},
  { id: "p-yt", name: "YouTube", icon: "youtube", feeds: [
    { id: "f-veritasium", name: "Veritasium", mono: "V", color: "#cf2b2b", count: 1 },
    { id: "f-rauno",      name: "Rauno Freiberg", mono: "R", color: "#cf2b2b", count: 1 },
  ]},
];

// ── folder tree ──────────────────────────────────────────────
const FOLDERS = [
  { id: "fo-tech", name: "技术", children: [
    { id: "fo-fe", name: "前端工程", count: 4 },
    { id: "fo-ai", name: "AI / LLM", count: 5 },
  ]},
  { id: "fo-product", name: "产品思考", count: 3 },
  { id: "fo-design",  name: "设计灵感", count: 2 },
  { id: "fo-life",    name: "生活方式", count: 1 },
];

function coverBg(h) {
  return `radial-gradient(120% 90% at 16% 10%, rgba(255,253,249,.55), transparent 54%),`
       + `linear-gradient(145deg, oklch(0.84 0.045 ${h}), oklch(0.71 0.06 ${(h + 32) % 360}))`;
}

// ── items ────────────────────────────────────────────────────
const ITEMS = [
  {
    id: "a1", type: "article", kind: "web", source: "Ink & Switch", author: "Martin Kleppmann 等",
    title: "Local-First Software:你拥有自己的数据",
    excerpt: "云端应用让协作变得轻松,代价却是你不再真正拥有数据。本地优先,是把所有权还给用户的一种尝试。",
    time: "上午 9:24", ts: 100, readingTime: 11, lang: "en",
    tags: ["t-deep", "t-eff"], folder: "fo-product", fav: true, unread: false, progress: 0.42,
    hue: 255, hasCover: true,
    body: [
      { t: "lead", lang: "en",
        text: `Cloud apps like Google Docs and Trello are popular because they enable real-time collaboration, and because you can reach your data from any device. But the price is steep: you no longer truly own that data.`,
        tr: `像 Google Docs、Trello 这样的云端应用之所以流行,是因为它们支持实时协作,也因为你能在任何设备上访问数据。但代价高昂:你不再真正拥有这些数据。` },
      { t: "p", lang: "en",
        text: `If the company behind the service shuts it down — or simply decides your account is no longer welcome — your documents can vanish overnight. The software you rely on every day is, in the end, borrowed.`,
        tr: `一旦背后的公司关停服务,或者只是认定你的账号不再受欢迎,你的文档就可能在一夜之间消失。你每天依赖的软件,说到底只是借来的。` },
      { t: "h2", lang: "en", text: `Seven ideals for local-first software`, tr: `本地优先软件的七个理想` },
      { t: "p", lang: "en",
        text: `We call an application “local-first” when it keeps the primary copy of your data on your own device, while still supporting the seamless collaboration we have come to expect from the cloud. The network becomes an enhancement, not a requirement.`,
        tr: `当一个应用把数据的主副本保存在你自己的设备上,同时仍能提供我们已习惯的云端式无缝协作时,我们称它为“本地优先”。网络成了一种增强,而不是必需品。` },
      { t: "p", lang: "en",
        text: `Fast. There is no spinner waiting on a server round-trip — your edits land instantly because they touch local storage first, then sync quietly in the background.`,
        tr: `快。没有等待服务器往返的转圈动画——你的编辑会立刻生效,因为它们先写入本地存储,再在后台静静同步。` },
      { t: "quote", lang: "en",
        text: `The data is yours, and the software is merely a lens through which you view and edit it.`,
        tr: `数据是你的,软件只是你查看和编辑它的一面镜片。` },
      { t: "p", lang: "en",
        text: `Offline by default. A flaky connection on a train should never stop you from reading or writing; sync simply resumes when the network does. And because the bytes live with you, the work you make today should still open in a decade.`,
        tr: `默认离线可用。火车上时断时续的信号,不该阻止你阅读或书写;网络恢复时,同步会自然续上。而且因为数据就在你身边,你今天创作的东西,十年后也应当还能打开。` },
    ],
    highlights: [
      { q: "The network becomes an enhancement, not a requirement.", note: "" },
      { q: "the work you make today should still open in a decade", note: "这正是我做这个 Reader 的初衷:数据留在本地。" },
    ],
    summary: {
      text: [
        "“本地优先”主张把数据的主副本存在用户设备上,网络只作增强而非前提,以此重新赋予用户对数据的所有权与长期可用性。",
        "文章提出了一套理想属性:快速响应、多设备、默认离线、长期留存,并强调软件只是数据的“镜片”。",
      ],
      keys: [
        "数据主副本存在本地设备,而非厂商服务器",
        "网络是增强项,离线是默认能力",
        "本地优先 ≈ 即时响应 + 后台同步(常借助 CRDT 实现)",
      ],
      tagSuggest: ["本地优先", "CRDT", "数据所有权"],
    },
  },
  {
    id: "a2", type: "rss", kind: "rss", source: "阮一峰的网络日志", feedId: "f-ruanyf", author: "阮一峰",
    title: "科技爱好者周刊(第 290 期):本地大模型的一年",
    excerpt: "过去一年,在笔记本上跑大模型从奇技淫巧变成了日常。这一期聊聊本地推理、量化,以及它对隐私的意义。",
    time: "昨天", ts: 95, readingTime: 8, lang: "zh",
    tags: ["t-ai", "t-eff"], folder: "fo-ai", fav: false, unread: true, progress: 0,
    hue: 28, hasCover: true,
    body: [
      { t: "lead", lang: "zh", text: `这一年最大的变化,是“在自己电脑上跑大模型”从极客的玩具,变成了普通人也能用的工具。` , tr: `The biggest change this year is that "running a large model on your own computer" went from a geek's toy to a tool ordinary people can use.`},
      { t: "p", lang: "zh", text: `得益于模型量化和更好的推理框架,一台几年前的笔记本也能流畅运行 7B 级别的模型。本地推理意味着你的数据不必离开设备——这与本地优先的理念不谋而合。`, tr: `Thanks to quantization and better inference runtimes, even a laptop from a few years ago can run a 7B model smoothly. Local inference means your data never has to leave the device.` },
      { t: "p", lang: "zh", text: `本期还推荐了几个开源工具,帮助你把网页、PDF 一键存入本地知识库,再用本地模型做摘要和问答。`, tr: `This issue also recommends a few open-source tools for saving web pages and PDFs into a local knowledge base, then using a local model to summarize and answer questions.` },
    ],
    highlights: [ { q: "本地推理意味着你的数据不必离开设备", note: "" } ],
    summary: {
      text: ["本期周刊聚焦“本地大模型”这一年的演进:量化与推理框架的进步,让消费级设备也能流畅运行中等规模模型。"],
      keys: ["量化让旧笔记本也能跑 7B 模型", "本地推理 = 数据不出设备", "推荐了网页/PDF 入库 + 本地问答的工具链"],
      tagSuggest: ["本地模型", "量化", "隐私"],
    },
  },
  {
    id: "a3", type: "x", kind: "x", source: "@karpathy", feedId: "f-karpathy", author: "Andrej Karpathy",
    title: "关于 LLM agent 的一段长推:不要把 agent 当成魔法",
    excerpt: "An agent is just a loop: model proposes an action, you run it, feed the result back. The hard part isn't the loop — it's the tools and the verification.",
    time: "周一", ts: 80, readingTime: 3, lang: "en",
    tags: ["t-ai"], folder: "fo-ai", fav: false, unread: true, progress: 0,
    hue: 268, hasCover: false,
    body: [
      { t: "p", lang: "en", text: `An "agent" is just a loop: the model proposes an action, your harness runs it, and you feed the result back. People over-mystify this.`, tr: `所谓“agent”不过是一个循环:模型提出一个动作,你的执行框架运行它,再把结果喂回去。人们把它过度神秘化了。` },
      { t: "p", lang: "en", text: `The hard part is never the loop. It's (1) the quality of the tools you expose, and (2) verification — knowing when the model is wrong before it compounds.`, tr: `难点从来不是循环本身,而是 (1) 你暴露给它的工具的质量,以及 (2) 验证——在错误累积之前就发现模型出错了。` },
      { t: "p", lang: "en", text: `Reading apps are a surprisingly good testbed: summarize, translate, cross-reference — small, verifiable tools over text you already trust.`, tr: `阅读类应用是个出乎意料好的试验场:摘要、翻译、交叉引用——都是建立在你已信任的文本之上、小而可验证的工具。` },
    ],
    highlights: [],
    summary: {
      text: ["Karpathy 认为 agent 的本质只是“提议-执行-反馈”的循环,真正困难的是工具质量与验证机制。"],
      keys: ["agent = 提议→执行→反馈 的循环", "难点在工具质量与“何时判定模型出错”", "阅读类应用是验证小工具的好场景"],
      tagSuggest: ["agent", "工具", "验证"],
    },
  },
  {
    id: "a4", type: "youtube", kind: "youtube", source: "Veritasium", feedId: "f-veritasium", author: "Derek Muller",
    title: "Dijkstra 最短路径算法,到底在做什么?",
    excerpt: "一个关于贪心、优先队列和地图导航的可视化讲解。28 分钟看懂图论里最优雅的算法之一。",
    time: "周日", ts: 70, duration: "28:14", lang: "en",
    tags: ["t-fe"], folder: "fo-fe", fav: true, unread: false, progress: 0.18,
    hue: 8, hasCover: true,
    body: [
      { t: "p", lang: "zh", text: `这是一个视频条目。Reader 会保存视频封面、时长与字幕,并记住你的播放进度。`, tr: `This is a video item. Reader saves the thumbnail, duration and transcript, and remembers your playback position.` },
      { t: "p", lang: "en", text: `Transcript · 00:42 — "Imagine every road on a map has a length. Dijkstra's algorithm finds the shortest route by always expanding the closest unvisited place next…"`, tr: `字幕 · 00:42 ——“想象地图上每条路都有长度。Dijkstra 算法总是优先扩展距离最近、尚未访问的地点,从而找到最短路径……”` },
    ],
    highlights: [],
    summary: {
      text: ["视频用地图导航类比讲解 Dijkstra 算法:借助优先队列,每次扩展当前距离起点最近的节点,直到抵达目标。"],
      keys: ["核心是贪心 + 优先队列", "每次扩展“最近的未访问节点”", "适合非负权重的最短路径"],
      tagSuggest: ["算法", "图论", "可视化"],
    },
  },
  {
    id: "a5", type: "weibo", kind: "weibo", source: "@阑夕", feedId: "f-lanxi", author: "阑夕",
    title: "一段关于“收藏即阅读”错觉的思考",
    excerpt: "我们收藏了太多“以后再看”,结果它们成了数字仓鼠的窝。真正的阅读发生在你愿意删掉收藏的那一刻。",
    time: "上周五", ts: 60, readingTime: 2, lang: "zh",
    tags: ["t-idea"], folder: "fo-product", fav: false, unread: false, progress: 1,
    hue: 340, hasCover: false,
    body: [
      { t: "p", lang: "zh", text: `我们收藏了太多“以后再看”,结果它们成了数字仓鼠的窝。点击“收藏”那一下的满足感,常常被误当成了阅读本身。`, tr: `We save far too many "read it later"s, and they become a digital hoarder's nest. The little hit of satisfaction from tapping "save" gets mistaken for reading itself.` },
      { t: "p", lang: "zh", text: `真正的阅读,也许发生在你愿意把一条收藏删掉的那一刻——要么读完了,要么终于承认不会读了。`, tr: `Real reading perhaps happens the moment you're willing to delete a saved item — either you've finished it, or you finally admit you never will.` },
    ],
    highlights: [ { q: "点击“收藏”那一下的满足感,常常被误当成了阅读本身", note: "设计提醒:别让收藏变成逃避阅读的出口。" } ],
    summary: {
      text: ["作者指出“收藏”带来的满足感常被误认为阅读,真正的消化发生在你愿意清理收藏(读完或放弃)之时。"],
      keys: ["收藏 ≠ 阅读", "满足感来自“存下来”的动作", "清理收藏才是消化的标志"],
      tagSuggest: ["阅读习惯", "产品", "反思"],
    },
  },
  {
    id: "a6", type: "pdf", kind: "pdf", source: "附件 · PDF", author: "Vaswani et al., 2017",
    title: "Attention Is All You Need.pdf",
    excerpt: "Transformer 原始论文。15 页,已提取全文与图表,可被 AI 摘要与问答检索。",
    time: "06/02", ts: 50, readingTime: 22, lang: "en",
    tags: ["t-ai", "t-deep"], folder: "fo-ai", fav: true, unread: false, progress: 0.65,
    hue: 210, hasCover: false,
    body: [
      { t: "p", lang: "en", text: `The dominant sequence transduction models are based on complex recurrent or convolutional neural networks. We propose a new simple architecture, the Transformer, based solely on attention mechanisms.`, tr: `主流的序列转换模型都基于复杂的循环或卷积神经网络。我们提出一种全新的简单架构——Transformer,它完全建立在注意力机制之上。` },
      { t: "p", lang: "en", text: `Experiments show these models to be superior in quality while being more parallelizable and requiring significantly less time to train.`, tr: `实验表明,这类模型质量更高,同时更易并行化,训练所需时间也大幅减少。` },
    ],
    highlights: [],
    summary: {
      text: ["这篇 2017 年的论文提出 Transformer 架构,完全依赖自注意力机制,摒弃循环与卷积,显著提升并行度与训练效率。"],
      keys: ["完全基于注意力,去掉 RNN/CNN", "更易并行、训练更快", "奠定了此后大模型的基础"],
      tagSuggest: ["Transformer", "注意力机制", "论文"],
    },
  },
  {
    id: "a7", type: "note", kind: "markdown", source: "我的笔记", author: "我",
    title: "周回顾 · 2026-W23",
    excerpt: "本周读完 3 篇长文,关于本地优先和 agent。下周想动手做一个本地阅读器的原型……",
    time: "06/07", ts: 40, readingTime: 1, lang: "zh",
    tags: ["t-eff"], folder: "fo-life", fav: false, unread: false, progress: 0,
    hue: 140, hasCover: false,
    body: [
      { t: "h2", lang: "zh", text: `做了什么`, tr: `` },
      { t: "p", lang: "zh", text: `读完 3 篇长文(本地优先、LLM agent、Transformer),用 Reader 的双语对照读完了 Kleppmann 那篇,做了 6 处高亮。`, tr: `` },
      { t: "h2", lang: "zh", text: `下周计划`, tr: `` },
      { t: "p", lang: "zh", text: `动手做一个“数据全在本地”的阅读器原型:三栏布局 + 划词 + AI 摘要。先把采集和阅读跑通。`, tr: `` },
    ],
    highlights: [],
    summary: { text: ["本周读完三篇长文并做了高亮;下周计划动手做本地优先阅读器原型,优先打通采集与阅读。"], keys: ["读完 3 篇长文 + 6 处高亮", "下周做本地阅读器原型", "先跑通采集与阅读"], tagSuggest: ["周回顾", "计划"] },
  },
  {
    id: "a8", type: "rss", kind: "rss", source: "Stratechery", feedId: "f-strat", author: "Ben Thompson",
    title: "The AI Hardware Question",
    excerpt: "Why the most interesting AI story of the year might not be a model at all, but where the inference happens — cloud, edge, or your own desk.",
    time: "06/06", ts: 35, readingTime: 9, lang: "en",
    tags: ["t-ai", "t-deep"], folder: "fo-product", fav: false, unread: true, progress: 0,
    hue: 220, hasCover: true,
    body: [
      { t: "lead", lang: "en", text: `The most interesting AI question of the year may not be about any single model, but about geography: where, physically, does inference happen?`, tr: `今年最有趣的 AI 问题,也许与任何单一模型无关,而是关于“地理”:推理究竟在物理上发生在哪里?` },
      { t: "p", lang: "en", text: `If inference moves to the edge — to phones and laptops — the economics of the entire industry shift, and so does the privacy calculus for users.`, tr: `如果推理迁移到边缘端——手机和笔记本——整个行业的经济模型都会改变,用户的隐私权衡也随之改变。` },
    ],
    highlights: [],
    summary: { text: ["Thompson 认为今年关键的 AI 命题是“推理发生在哪里”:一旦推理下沉到端侧,行业经济与隐私格局都将重塑。"], keys: ["关键问题:推理的物理位置", "端侧推理改变行业经济模型", "也改变用户隐私权衡"], tagSuggest: ["AI", "硬件", "端侧"] },
  },
  {
    id: "a9", type: "image", kind: "image", source: "附件 · 图片", author: "我",
    title: "设计灵感:Things 3 的空状态",
    excerpt: "截了一张 Things 3 的空状态截图,留白和插画都很克制。存进“设计灵感”。",
    time: "06/05", ts: 30, readingTime: 1, lang: "zh",
    tags: ["t-design", "t-idea"], folder: "fo-design", fav: false, unread: false, progress: 0,
    hue: 48, hasCover: true,
    body: [
      { t: "p", lang: "zh", text: `存了一张截图。Reader 会保留原图,并允许你加标签、写一句注释。`, tr: `Saved a screenshot. Reader keeps the original image and lets you add tags and a one-line note.` },
      { t: "img", hue: 48, cap: "Things 3 空状态:克制的留白与一句温和的提示。" },
    ],
    highlights: [],
    summary: { text: ["保存的一张 Things 3 空状态截图,作为设计参考:留白克制、文案温和。"], keys: ["空状态设计参考", "留白克制", "文案温和友好"], tagSuggest: ["空状态", "留白", "Things"] },
  },
  {
    id: "a10", type: "rss", kind: "rss", source: "少数派", feedId: "f-sspai", author: "化学心情",
    title: "我的 macOS 效率工作流:用快捷键串起一切",
    excerpt: "从 Raycast 到自定义快捷键,一篇关于如何让 Mac 听话的实操指南。",
    time: "06/03", ts: 20, readingTime: 6, lang: "zh",
    tags: ["t-eff", "t-fe"], folder: "fo-life", fav: false, unread: true, progress: 0,
    hue: 162, hasCover: true,
    body: [
      { t: "p", lang: "zh", text: `好的效率工具应该是“看不见”的:你按下一个组合键,事情就发生了,而不必离开当前的心流。`, tr: `Good productivity tools should be "invisible": you press a chord and the thing just happens, without leaving your current flow.` },
      { t: "p", lang: "zh", text: `我把最常用的动作都绑到了 ⌘K 命令面板里——搜索、跳转、新建,一个入口全搞定。`, tr: `I bound all my most-used actions to a ⌘K command palette — search, jump, create, all from a single entry point.` },
    ],
    highlights: [],
    summary: { text: ["作者分享 macOS 效率工作流,核心理念是让工具“隐形”,并用 ⌘K 命令面板统一收纳高频操作。"], keys: ["好工具应当“隐形”", "用快捷键维持心流", "⌘K 统一高频操作入口"], tagSuggest: ["效率", "快捷键", "Raycast"] },
  },
  {
    id: "a11", type: "x", kind: "x", source: "@rauchg", feedId: "f-rauchg", author: "Guillermo Rauch",
    title: "Local-first is the next big shift in app architecture",
    excerpt: "The pendulum swung all the way to the cloud. It's swinging back — but this time we keep the collaboration.",
    time: "06/01", ts: 12, readingTime: 2, lang: "en",
    tags: ["t-fe", "t-deep"], folder: "fo-fe", fav: false, unread: false, progress: 0,
    hue: 240, hasCover: false,
    body: [
      { t: "p", lang: "en", text: `The pendulum swung all the way to the cloud over the last decade. It's swinging back toward the device — but this time we get to keep the seamless collaboration.`, tr: `过去十年,钟摆完全摆向了云端。如今它正摆回设备这一侧——但这一次,我们可以同时保留无缝协作。` },
    ],
    highlights: [],
    summary: { text: ["Rauch 认为应用架构的下一次大转变是“本地优先”:钟摆从云端摆回设备,同时保留协作能力。"], keys: ["架构钟摆从云端摆回设备", "本地优先是下一次转变", "协作能力不再丢失"], tagSuggest: ["本地优先", "架构", "趋势"] },
  },
  {
    id: "a12", type: "youtube", kind: "youtube", source: "Rauno Freiberg", feedId: "f-rauno", author: "Rauno Freiberg",
    title: "细节即设计:微交互如何塑造产品质感",
    excerpt: "一段关于 hover、过渡与触感反馈的演讲。好的微交互让界面“活”起来。",
    time: "05/30", ts: 8, duration: "14:52", lang: "en",
    tags: ["t-design", "t-fe"], folder: "fo-design", fav: false, unread: false, progress: 0,
    hue: 300, hasCover: true,
    body: [
      { t: "p", lang: "en", text: `Microinteractions — the hover, the spring, the haptic tick — are not decoration. They are how an interface tells you it heard you.`, tr: `微交互——悬停、弹性、轻微的触感反馈——不是装饰。它们是界面在告诉你:“我收到了。”` },
    ],
    highlights: [],
    summary: { text: ["演讲强调微交互(悬停、过渡、触感)并非装饰,而是界面对用户操作的回应,决定了产品质感。"], keys: ["微交互不是装饰", "它是界面对操作的回应", "细节决定产品质感"], tagSuggest: ["微交互", "设计", "质感"] },
  },
];

// ── AI chat seed + suggestions + remix ───────────────────────
const SEED_CHAT = [
  { role: "bot", text: "我可以围绕你正在读的这篇文章帮忙:翻译、摘要、提炼要点,或与你收藏夹里的其他内容交叉对比。试试下面的快捷指令,或直接提问。", cites: [] },
];
const CHAT_SUGGEST = ["用三句话总结这篇", "和我收藏的其他 3 篇本地优先文章有何异同?", "把要点整理成一条微博", "解释文中的 CRDT"];
const REMIX = [
  { id: "rx-note",  icon: "doc",     title: "整理成读书笔记",   desc: "提炼要点 + 我的高亮,生成 Markdown 笔记" },
  { id: "rx-thread",icon: "x",       title: "改写成 X 推文串",   desc: "把长文压缩成 5 条推文的 thread" },
  { id: "rx-weekly",icon: "calendar",title: "汇入本周周报",     desc: "合并本周读过的内容,生成回顾草稿" },
  { id: "rx-cross", icon: "sparkles",title: "跨文章二次创作",   desc: "选取多篇内容,生成一篇综述短文" },
];

function fmtCount(n) { return n > 99 ? "99+" : String(n); }

Object.assign(window, { SMART, TAGS, PLATFORMS, FOLDERS, ITEMS, SEED_CHAT, CHAT_SUGGEST, REMIX, coverBg, fmtCount });
