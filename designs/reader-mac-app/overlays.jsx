// overlays.jsx — ⌘K palette, capture/add modal, subscriptions manager

// ───────────────────────── command palette ─────────────────────────
function CommandPalette({ commands, items, onRunCommand, onOpenItem, onClose }) {
  const [q, setQ] = React.useState("");
  const [idx, setIdx] = React.useState(0);
  const inputRef = React.useRef(null);
  React.useEffect(() => { inputRef.current && inputRef.current.focus(); }, []);

  const ql = q.toLowerCase();
  const cmds = commands.filter((c) => !q || c.title.toLowerCase().includes(ql) || (c.keywords || "").includes(ql));
  const its = (!q ? items.slice(0, 5) : items.filter((i) => i.title.toLowerCase().includes(ql) || i.source.toLowerCase().includes(ql) || i.excerpt.toLowerCase().includes(ql))).slice(0, 7);
  const results = [...cmds.map((c) => ({ kind: "cmd", c })), ...its.map((i) => ({ kind: "item", i }))];
  React.useEffect(() => { setIdx(0); }, [q]);

  const run = (r) => { if (!r) return; r.kind === "cmd" ? onRunCommand(r.c) : onOpenItem(r.i.id); };
  const onKey = (e) => {
    if (e.key === "ArrowDown") { e.preventDefault(); setIdx((i) => Math.min(results.length - 1, i + 1)); }
    else if (e.key === "ArrowUp") { e.preventDefault(); setIdx((i) => Math.max(0, i - 1)); }
    else if (e.key === "Enter") { e.preventDefault(); run(results[idx]); }
  };

  let row = -1;
  return (
    <div className="scrim" onMouseDown={onClose}>
      <div className="palette" onMouseDown={(e) => e.stopPropagation()}>
        <div className="palette-input">
          <Icon name="search" size={19} />
          <input ref={inputRef} value={q} onChange={(e) => setQ(e.target.value)} onKeyDown={onKey} placeholder="搜索内容,或输入命令…" />
          <span className="kbd">esc</span>
        </div>
        <div className="palette-scroll">
          {cmds.length > 0 && <div className="palette-grouplabel">命令</div>}
          {cmds.map((c) => { row++; const a = row === idx; return (
            <div className={"palette-item" + (a ? " active" : "")} key={c.id} onMouseEnter={() => setIdx(row)} onClick={() => run({ kind: "cmd", c })}>
              <span className="pi-ico"><Icon name={c.icon} size={18} /></span>
              <div className="pi-main"><div className="pi-title">{c.title}</div>{c.sub && <div className="pi-sub">{c.sub}</div>}</div>
              {c.kbd && <span className="kbd">{c.kbd}</span>}
            </div>); })}
          {its.length > 0 && <div className="palette-grouplabel">内容</div>}
          {its.map((i) => { row++; const a = row === idx; return (
            <div className={"palette-item" + (a ? " active" : "")} key={i.id} onMouseEnter={() => setIdx(row)} onClick={() => run({ kind: "item", i })}>
              <span className="pi-ico" style={{ color: KIND_COLOR[i.kind] }}><Icon name={kindIcon(i.kind)} size={17} /></span>
              <div className="pi-main"><div className="pi-title">{i.title}</div><div className="pi-sub">{i.source} · {i.duration || i.readingTime + " 分钟"}</div></div>
            </div>); })}
          {results.length === 0 && <div className="list-empty">没有匹配项</div>}
        </div>
        <div className="palette-foot">
          <span className="k"><span className="kbd">↑</span><span className="kbd">↓</span> 选择</span>
          <span className="k"><span className="kbd">↵</span> 打开</span>
          <span className="k"><span className="kbd">⌘</span><span className="kbd">K</span> 唤起</span>
        </div>
      </div>
    </div>
  );
}

// ───────────────────────── capture / add modal ─────────────────────────
const ADD_TABS = [
  { id: "url", name: "网址", icon: "link" },
  { id: "file", name: "附件", icon: "paperclip" },
  { id: "md", name: "Markdown", icon: "markdown" },
  { id: "other", name: "其他", icon: "ellipsis" },
];
const FOLDER_FLAT = [{ id: "fo-fe", name: "前端工程" }, { id: "fo-ai", name: "AI / LLM" }, { id: "fo-product", name: "产品思考" }, { id: "fo-design", name: "设计灵感" }, { id: "fo-life", name: "生活方式" }];

function AddModal({ onClose, onSave }) {
  const [tab, setTab] = React.useState("url");
  const [url, setUrl] = React.useState("");
  const [fetched, setFetched] = React.useState(false);
  const [title, setTitle] = React.useState("");
  const [md, setMd] = React.useState("");
  const [tags, setTags] = React.useState(new Set());
  const [folder, setFolder] = React.useState("fo-product");

  const domain = (() => { try { return new URL(url.startsWith("http") ? url : "https://" + url).hostname.replace(/^www\./, ""); } catch { return url || "网页"; } })();
  const toggleTag = (id) => { const n = new Set(tags); n.has(id) ? n.delete(id) : n.add(id); setTags(n); };

  const save = () => {
    const base = { tags: [...tags], folder, time: "刚刚", ts: 999, unread: true, fav: false, progress: 0, hue: 200 + (url.length + title.length) % 140 };
    if (tab === "url") onSave({ ...base, type: "article", kind: "web", source: domain, author: domain, title: title || "来自 " + domain + " 的文章", excerpt: "已自动抓取正文与配图,可立即阅读、翻译或摘要。", readingTime: 6, lang: "zh", hasCover: true, body: [{ t: "lead", lang: "zh", text: "这是从 " + domain + " 抓取的内容正文。Reader 已保存全文与图片到本地。", tr: "" }] });
    else if (tab === "md") onSave({ ...base, type: "note", kind: "markdown", source: "我的笔记", author: "我", title: title || "无标题笔记", excerpt: md.slice(0, 60) || "一篇 Markdown 笔记", readingTime: 2, lang: "zh", hasCover: false, body: [{ t: "p", lang: "zh", text: md || "（空白笔记）", tr: "" }] });
    else if (tab === "file") onSave({ ...base, type: "pdf", kind: "pdf", source: "附件 · PDF", author: "本地文件", title: title || "新附件.pdf", excerpt: "已导入本地附件,可提取全文做摘要与问答。", readingTime: 10, lang: "zh", hasCover: false, body: [{ t: "p", lang: "zh", text: "附件已保存到本地。", tr: "" }] });
    else onSave({ ...base, type: "article", kind: "web", source: "快速收藏", author: "我", title: title || "快速收藏", excerpt: "通过其他方式收藏的内容。", readingTime: 3, lang: "zh", hasCover: false, body: [{ t: "p", lang: "zh", text: "内容已收藏到本地。", tr: "" }] });
  };

  return (
    <div className="scrim" style={{ alignItems: "center" }} onMouseDown={onClose}>
      <div className="modal" onMouseDown={(e) => e.stopPropagation()}>
        <div className="modal-head"><Icon name="plus" size={18} /><span className="mt">添加内容</span><button className="icon-btn sm" onClick={onClose}><Icon name="close" size={16} /></button></div>
        <div className="modal-tabs">
          {ADD_TABS.map((t) => <button key={t.id} className={"modal-tab" + (tab === t.id ? " on" : "")} onClick={() => setTab(t.id)}><Icon name={t.icon} size={15} />{t.name}</button>)}
        </div>
        <div className="modal-body">
          {tab === "url" && (<>
            <div className="field"><label>网址</label>
              <div className="url-inp"><Icon name="link" size={16} /><input autoFocus value={url} onChange={(e) => { setUrl(e.target.value); setFetched(false); }} placeholder="粘贴文章 / 视频 / 推文链接…" /><button className="go" onClick={() => { setFetched(true); setTitle("来自 " + domain + " 的文章"); }}>抓取</button></div>
            </div>
            {fetched && (<div className="fetched"><div className="th" style={{ background: coverBg(210) }} /><div style={{ minWidth: 0 }}><div className="ft">{title}</div><div className="fm">{domain} · 自动提取 · 约 6 分钟</div><div className="fx">已抓取正文、标题与首图,排版已清理。保存后即可在本地阅读、翻译与摘要。</div></div></div>)}
          </>)}
          {tab === "file" && (<div className="drop"><div className="di"><Icon name="paperclip" size={40} /></div><div className="dt">拖入 PDF、视频或图片</div><div className="ds">或点击从本地选择 · 文件将保存在本地</div></div>)}
          {tab === "md" && (<>
            <div className="field"><label>标题</label><input className="inp" value={title} onChange={(e) => setTitle(e.target.value)} placeholder="给这篇笔记起个名字" /></div>
            <div className="field"><label>正文(Markdown)</label><textarea value={md} onChange={(e) => setMd(e.target.value)} placeholder={"# 标题\n\n支持 **加粗**、*斜体*、> 引用、- 列表…"} /></div>
          </>)}
          {tab === "other" && (<div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
            {[{ i: "copy", t: "从剪贴板粘贴", d: "自动识别链接或纯文本" }, { i: "rss", t: "邮件转发收件地址", d: "把 Newsletter 转发到 inbox@local" }, { i: "globe", t: "浏览器扩展", d: "在任意网页一键保存到本地" }].map((o) => (
              <div className="remix-opt" key={o.t}><span className="ico"><Icon name={o.i} size={17} /></span><div style={{ flex: 1 }}><div className="tt">{o.t}</div><div className="dd">{o.d}</div></div></div>
            ))}
          </div>)}

          {tab !== "other" && tab !== "file" && (<>
            <div className="field"><label>标签</label><div className="chips-row">{TAGS.map((t) => <span key={t.id} className="chip" onClick={() => toggleTag(t.id)} style={tags.has(t.id) ? { background: t.color, color: "#fff" } : null}><span className="tdot" style={{ background: tags.has(t.id) ? "#fff" : t.color }} />{t.name}</span>)}</div></div>
            <div className="field"><label>目录</label><div className="chips-row">{FOLDER_FLAT.map((f) => <span key={f.id} className="chip" onClick={() => setFolder(f.id)} style={folder === f.id ? { background: "var(--accent)", color: "#fff" } : null}><Icon name="folder" size={12} />{f.name}</span>)}</div></div>
          </>)}
        </div>
        <div className="modal-foot"><span className="sp" /><button className="btn ghost" onClick={onClose}>取消</button><button className="btn primary" onClick={save}>保存到本地</button></div>
      </div>
    </div>
  );
}

// ───────────────────────── subscriptions manager ─────────────────────────
function SubsModal({ onClose, onToast }) {
  const [on, setOn] = React.useState(() => { const m = {}; PLATFORMS.forEach((p) => p.feeds.forEach((f) => { m[f.id] = true; })); return m; });
  return (
    <div className="scrim" style={{ alignItems: "center" }} onMouseDown={onClose}>
      <div className="modal wide" onMouseDown={(e) => e.stopPropagation()}>
        <div className="modal-head"><Icon name="rss" size={18} /><span className="mt">管理订阅源</span><button className="icon-btn sm" onClick={onClose}><Icon name="close" size={16} /></button></div>
        <div className="modal-body">
          <div className="url-inp" style={{ marginBottom: 16 }}><Icon name="plus" size={16} /><input placeholder="添加 RSS 链接、X / 微博 / YouTube 账号…" /><button className="go" onClick={() => onToast("已添加订阅源")}>订阅</button></div>
          {PLATFORMS.map((p) => (
            <div key={p.id} style={{ marginBottom: 8 }}>
              <div className="side-label" style={{ paddingLeft: 2 }}><span style={{ display: "inline-flex", alignItems: "center", gap: 7 }}><Icon name={p.icon} size={14} />{p.name}</span></div>
              {p.feeds.map((f) => (
                <div className="sub-row" key={f.id}>
                  <span className="avatar round" style={{ width: 30, height: 30, fontSize: 13, background: f.color }}>{f.mono}</span>
                  <div className="meta"><div className="nm">{f.name}</div><div className="url">每小时检查 · {f.count} 条未读</div></div>
                  <span className="freq">{on[f.id] ? "已开启" : "已暂停"}</span>
                  <div className={"toggle" + (on[f.id] ? " on" : "")} onClick={() => setOn({ ...on, [f.id]: !on[f.id] })}><i /></div>
                </div>
              ))}
            </div>
          ))}
        </div>
        <div className="modal-foot"><span style={{ fontSize: 12, color: "var(--text-3)" }}>所有订阅内容都会下载并保存到本地</span><span className="sp" /><button className="btn primary" onClick={onClose}>完成</button></div>
      </div>
    </div>
  );
}

Object.assign(window, { CommandPalette, AddModal, SubsModal, ADD_TABS });
