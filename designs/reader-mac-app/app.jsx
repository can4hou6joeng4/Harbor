// app.jsx — App orchestrator: state, filtering, commands, keyboard, AI simulation

const FEED_PLATFORM = {};
const PLATFORM_FEEDS = {};
PLATFORMS.forEach((p) => { PLATFORM_FEEDS[p.id] = p.feeds.map((f) => f.id); p.feeds.forEach((f) => { FEED_PLATFORM[f.id] = p.id; }); });
const FOLDER_CHILDREN = {}; FOLDERS.forEach((f) => { if (f.children) FOLDER_CHILDREN[f.id] = f.children.map((c) => c.id); });
const NAME_OF = {};
SMART.forEach((s) => NAME_OF[s.id] = s.name);
PLATFORMS.forEach((p) => { NAME_OF[p.id] = p.name; p.feeds.forEach((f) => NAME_OF[f.id] = f.name); });
FOLDERS.forEach((f) => { NAME_OF[f.id] = f.name; (f.children || []).forEach((c) => NAME_OF[c.id] = c.name); });
TAGS.forEach((t) => NAME_OF[t.id] = t.name);

const load = (k, d) => { try { const v = localStorage.getItem("reader-" + k); return v === null ? d : JSON.parse(v); } catch { return d; } };

function inView(item, view) {
  if (view === "all") return true;
  if (view === "inbox") return item.unread || (item.progress > 0 && item.progress < 1);
  if (view === "unread") return item.unread;
  if (view === "fav") return item.fav;
  if (view === "later") return item.progress > 0 && item.progress < 1;
  if (view === "archive") return false;
  if (PLATFORM_FEEDS[view]) return PLATFORM_FEEDS[view].includes(item.feedId);
  if (FOLDER_CHILDREN[view]) return FOLDER_CHILDREN[view].includes(item.folder) || item.folder === view;
  if (view.startsWith("f-")) return item.feedId === view;
  if (view.startsWith("fo-")) return item.folder === view;
  if (view.startsWith("t-")) return item.tags && item.tags.includes(view);
  return true;
}

function generateReply(text, item) {
  const t = text.toLowerCase();
  const k = (item.summary && item.summary.keys) || [];
  if (/总结|摘要|三句|概括|要点/.test(text))
    return { text: item.summary.text[0] + "\n\n核心要点:" + k.join(";"), cites: [item.source] };
  if (/翻译/.test(text))
    return { text: "已为你处理这段翻译。大意是围绕「" + (item.summary.tagSuggest[0] || "核心议题") + "」展开。\n\n提示:点开阅读区顶部的「双语对照」,可以逐段对照原文与译文。", cites: [item.source] };
  if (/微博|推文|thread|改写|创作|整理成/.test(text))
    return { text: "草拟了一条:\n\n" + (item.title + "——" + (k[0] || "")) + "\n\n要更口语、更短,还是配上我的高亮?可以到「二创」标签里换个模板。", cites: [item.source] };
  if (/crdt/i.test(text))
    return { text: "CRDT(无冲突复制数据类型)是一类数据结构:多个副本各自离线修改后,合并时能自动收敛到一致结果、无需中央服务器裁决。这正是「本地优先」实现实时协作的关键技术。", cites: [item.source] };
  if (/异同|对比|交叉|其他/.test(text))
    return { text: "在你收藏夹里和「本地优先」相关的几篇中:\n\n· 这篇强调数据所有权与长期可用;\n· @rauchg 那条更看重架构钟摆;\n· 阮一峰周刊则落在端侧推理。\n\n共同结论:把数据留在本地,同时不放弃协作。", cites: ["本地优先", "@rauchg", "科技爱好者周刊"] };
  return { text: "围绕《" + item.title + "》,我的理解是:" + (k[0] || item.excerpt) + "。\n\n需要我做一句话摘要、翻译,还是改写成读书笔记?", cites: [item.source] };
}

function App() {
  const [theme, setTheme] = React.useState(() => load("theme", "light"));
  const [items, setItems] = React.useState(ITEMS);
  const [view, setView] = React.useState("inbox");
  const [selectedId, setSelectedId] = React.useState("a1");
  const [query, setQuery] = React.useState("");
  const [sort, setSort] = React.useState("new");

  const [aiOpen, setAiOpen] = React.useState(true);
  const [aiTab, setAiTab] = React.useState("summary");
  const [messages, setMessages] = React.useState(SEED_CHAT);
  const [sending, setSending] = React.useState(false);

  const [serif, setSerif] = React.useState(() => load("serif", true));
  const [font, setFont] = React.useState(() => load("font", 18));
  const [line, setLine] = React.useState(() => load("line", 1.78));
  const [width, setWidth] = React.useState(() => load("width", 680));
  const [bilingual, setBilingual] = React.useState(() => load("biling", true));
  const [typoOpen, setTypoOpen] = React.useState(false);

  const [paletteOpen, setPaletteOpen] = React.useState(false);
  const [addOpen, setAddOpen] = React.useState(false);
  const [subsOpen, setSubsOpen] = React.useState(false);
  const [toast, setToast] = React.useState(null);

  React.useEffect(() => { document.documentElement.setAttribute("data-theme", theme); }, [theme]);
  React.useEffect(() => { localStorage.setItem("reader-theme", JSON.stringify(theme)); }, [theme]);
  React.useEffect(() => { localStorage.setItem("reader-serif", JSON.stringify(serif)); localStorage.setItem("reader-font", JSON.stringify(font)); localStorage.setItem("reader-line", JSON.stringify(line)); localStorage.setItem("reader-width", JSON.stringify(width)); localStorage.setItem("reader-biling", JSON.stringify(bilingual)); }, [serif, font, line, width, bilingual]);

  const showToast = (m) => { setToast(m); clearTimeout(window.__t); window.__t = setTimeout(() => setToast(null), 2200); };

  // derived list
  const visible = React.useMemo(() => {
    const q = query.trim().toLowerCase();
    let list = items.filter((i) => inView(i, view));
    if (q) list = list.filter((i) => (i.title + i.excerpt + i.source).toLowerCase().includes(q) || (i.tags || []).some((id) => (NAME_OF[id] || "").toLowerCase().includes(q)));
    list = [...list];
    if (sort === "new") list.sort((a, b) => b.ts - a.ts);
    else if (sort === "old") list.sort((a, b) => a.ts - b.ts);
    else if (sort === "unread") list.sort((a, b) => (b.unread - a.unread) || (b.ts - a.ts));
    return list;
  }, [items, view, query, sort]);

  const selected = items.find((i) => i.id === selectedId) || null;

  const selectItem = (id) => { setSelectedId(id); setItems((prev) => prev.map((i) => i.id === id ? { ...i, unread: false } : i)); };
  const toggleFav = (id) => { setItems((prev) => prev.map((i) => i.id === id ? { ...i, fav: !i.fav } : i)); };
  const setProgress = (id, pct) => { setItems((prev) => prev.map((i) => i.id === id ? { ...i, progress: pct } : i)); };
  const addHighlight = (id, q, note) => {
    setItems((prev) => prev.map((i) => i.id === id ? { ...i, highlights: [...(i.highlights || []).filter((h) => h.q !== q), { q, note }] } : i));
    showToast(note ? "已保存高亮 + 笔记" : "已高亮");
  };
  const markAllRead = () => { setItems((prev) => prev.map((i) => ({ ...i, unread: false }))); showToast("已全部标为已读"); };

  const sendMessage = (text) => {
    setAiOpen(true); setAiTab("chat");
    setMessages((m) => [...m, { role: "user", text, cites: [] }]);
    setSending(true);
    setTimeout(() => {
      setMessages((m) => [...m, { role: "bot", ...generateReply(text, selected || items[0]) }]);
      setSending(false);
    }, 800 + Math.random() * 500);
  };
  const askAI = (text) => sendMessage(text);

  const addItem = (draft) => {
    const id = "u" + (items.length + 1);
    const it = { id, highlights: [], summary: { text: ["这是你刚刚保存的内容,AI 可以为它生成摘要。"], keys: ["来源已保存到本地", "可打标签与归类", "支持翻译与二次创作"], tagSuggest: ["新收藏"] }, ...draft };
    setItems((prev) => [it, ...prev]);
    setAddOpen(false); setView("inbox"); setSelectedId(id); showToast("已保存到本地 · " + (draft.source || "新内容"));
  };

  const commands = [
    { id: "add", title: "添加内容", sub: "网址 / 附件 / Markdown", icon: "plus", kbd: "⌘N", keywords: "add url 采集 收藏", run: () => setAddOpen(true) },
    { id: "theme", title: "切换 亮 / 暗 外观", icon: theme === "dark" ? "sun" : "moon", keywords: "theme dark light 主题", run: () => setTheme((t) => t === "dark" ? "light" : "dark") },
    { id: "ai", title: "打开 AI 助手", icon: "sparkles", keywords: "ai 助手 chat", run: () => setAiOpen(true) },
    { id: "biling", title: "切换 双语对照", icon: "translate", keywords: "翻译 双语 translate", run: () => setBilingual((b) => !b) },
    { id: "serif", title: "切换 衬线阅读模式", icon: "doc", keywords: "字体 衬线 serif", run: () => setSerif((s) => !s) },
    { id: "subs", title: "管理订阅源", icon: "rss", keywords: "rss 订阅 subscribe", run: () => setSubsOpen(true) },
    { id: "readall", title: "全部标为已读", icon: "check", keywords: "已读 read", run: markAllRead },
    { id: "fav", title: "收藏 / 取消收藏当前", icon: "star", keywords: "收藏 star", run: () => selected && toggleFav(selected.id) },
  ];

  // keyboard
  const ref = React.useRef({});
  ref.current = { visible, selectedId, paletteOpen, addOpen, subsOpen };
  React.useEffect(() => {
    const onKey = (e) => {
      const S = ref.current;
      const typing = /INPUT|TEXTAREA/.test((e.target && e.target.tagName) || "");
      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === "k") { e.preventDefault(); setPaletteOpen((o) => !o); return; }
      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === "n") { e.preventDefault(); setAddOpen(true); return; }
      if (e.key === "Escape") { setPaletteOpen(false); setAddOpen(false); setSubsOpen(false); setTypoOpen(false); return; }
      if (typing || S.paletteOpen || S.addOpen || S.subsOpen) return;
      if (e.key === "j" || e.key === "k") {
        const idx = S.visible.findIndex((i) => i.id === S.selectedId);
        const next = e.key === "j" ? Math.min(S.visible.length - 1, idx + 1) : Math.max(0, idx - 1);
        if (S.visible[next]) selectItem(S.visible[next].id);
      }
      if (e.key === "f" && S.selectedId) toggleFav(S.selectedId);
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, []);

  const unreadCount = visible.filter((i) => i.unread).length;
  const subtitle = visible.length + " 篇" + (unreadCount ? " · " + unreadCount + " 未读" : "");

  return (
    <div className="window">
      <Sidebar activeView={view} onSelect={(v) => { setView(v); setQuery(""); }} items={items}
               onAdd={() => setAddOpen(true)} onManageSubs={() => setSubsOpen(true)}
               theme={theme} onToggleTheme={() => setTheme((t) => t === "dark" ? "light" : "dark")}
               onSettings={() => showToast("设置(演示)")} />

      <ListPane title={NAME_OF[view] || "全部"} subtitle={subtitle} items={visible}
                selectedId={selectedId} onSelect={selectItem} query={query} onQuery={setQuery}
                sort={sort} onSort={setSort} onFav={toggleFav} />

      <Reader item={selected} theme={theme} onSetTheme={setTheme}
              s={{ serif, font, line, width }}
              set={{ serif: setSerif, font: setFont, line: setLine, width: setWidth }}
              bilingual={bilingual} onSetBilingual={setBilingual}
              typoOpen={typoOpen} onTypoToggle={() => setTypoOpen((o) => !o)}
              aiOpen={aiOpen} onToggleAI={() => setAiOpen((o) => !o)}
              onFav={toggleFav} onProgress={setProgress}
              onHighlight={addHighlight} onAskAI={askAI} />

      {aiOpen && (
        <AIPanel item={selected} tab={aiTab} onTab={setAiTab} messages={messages} sending={sending}
                 onSend={sendMessage} onClose={() => setAiOpen(false)} items={items}
                 bilingual={bilingual} onSetBilingual={setBilingual} onToast={showToast} />
      )}

      {paletteOpen && <CommandPalette commands={commands} items={items}
                        onRunCommand={(c) => { setPaletteOpen(false); c.run(); }}
                        onOpenItem={(id) => { setPaletteOpen(false); selectItem(id); }}
                        onClose={() => setPaletteOpen(false)} />}
      {addOpen && <AddModal onClose={() => setAddOpen(false)} onSave={addItem} />}
      {subsOpen && <SubsModal onClose={() => setSubsOpen(false)} onToast={showToast} />}

      {toast && <div className="toast"><Icon name="check-circle" size={16} />{toast}</div>}
    </div>
  );
}

ReactDOM.createRoot(document.getElementById("root")).render(<App />);
