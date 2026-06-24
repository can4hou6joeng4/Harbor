// promo-ui.jsx — presentational Reader UI + promo overlays (driven by props)

/* ───────────────────────── Sidebar ───────────────────────── */
function SideItem({ icon, label, count, sel, leading, accent, indent }) {
  return (
    <div className={"side-item" + (sel ? " sel" : "") + (indent ? " " + indent : "")}>
      {leading}
      {icon && <span className="si-ico" style={accent ? { color: accent } : null}><Icon name={icon} size={16} /></span>}
      <span className="si-label">{label}</span>
      {count > 0 && <span className="count">{count}</span>}
    </div>
  );
}

function Sidebar({ theme, addPulse }) {
  return (
    <nav className="sidebar">
      <div className="side-top">
        <div className="traffic"><span className="tl r" /><span className="tl y" /><span className="tl g" /></div>
        <div style={{ flex: 1 }} />
        <button className="icon-btn sm"><Icon name={theme === "dark" ? "sun" : "moon"} size={16} /></button>
        <button className="icon-btn sm" style={addPulse ? { background: "var(--accent-soft)", color: "var(--accent-text)" } : null}>
          <Icon name="plus" size={17} />
        </button>
      </div>
      <div className="side-scroll">
        <div>{SMART.map((s) => <SideItem key={s.id} icon={s.icon} label={s.name} count={s.count} sel={s.sel} />)}</div>
        <div className="side-section">
          <div className="side-label"><span>订阅源</span><Icon name="plus" size={13} style={{ opacity: .4 }} /></div>
          <SideItem icon="rss" label="RSS" count={10} leading={<span className="tree-toggle open"><Icon name="chev" size={12} /></span>} />
          {FEEDS.map((f) => (
            <SideItem key={f.id} label={f.name} count={f.count} indent="indent"
                      leading={<span className="avatar round" style={{ background: f.color }}>{f.mono}</span>} />
          ))}
        </div>
        <div className="side-section">
          <div className="side-label"><span>目录</span></div>
          {FOLDERS.map((fo) => <SideItem key={fo.id} icon="folder" label={fo.name} count={fo.count}
                      leading={<span style={{ width: 14, flexShrink: 0 }} />} />)}
        </div>
        <div className="side-section">
          <div className="side-label"><span>标签</span></div>
          {TAGS.map((t) => <SideItem key={t.id} label={t.name}
                      leading={<span className="dot" style={{ background: t.color, marginLeft: 3, marginRight: 1 }} />} />)}
        </div>
      </div>
      <div style={{ padding: "9px 12px", borderTop: ".5px solid var(--sep)", display: "flex", alignItems: "center", gap: 8 }}>
        <span style={{ color: "#30c463", display: "inline-flex" }}><Icon name="check-circle" size={15} /></span>
        <span style={{ fontSize: 12, color: "var(--text-3)", flex: 1 }}>数据保存在本地</span>
        <button className="icon-btn sm"><Icon name="gear" size={16} /></button>
      </div>
    </nav>
  );
}

/* ───────────────────────── List pane ───────────────────────── */
const KIND_COLOR = { web: "var(--text-3)", rss: "#e0533d", x: "var(--text-2)", pdf: "#d8443a" };
const TAG_BY_ID = Object.fromEntries(TAGS.map((t) => [t.id, t]));

function ListCard({ item, sel, style }) {
  const itemTags = (item.tags || []).map((id) => TAG_BY_ID[id]).filter(Boolean);
  return (
    <article className={"card" + (sel ? " sel" : "") + (item.unread ? "" : " read")} style={style}>
      <div className="card-top">
        {item.unread && <span className="unread-dot" />}
        <div className="card-src">
          <span style={{ color: KIND_COLOR[item.kind] || "var(--text-3)", display: "inline-flex", flexShrink: 0 }}><Icon name={kindIcon(item.kind)} size={13} /></span>
          <span className="src-name">{item.source}</span>
        </div>
        <span style={{ color: item.fav ? "var(--star)" : "var(--text-4)", display: "inline-flex" }}><Icon name={item.fav ? "star-fill" : "star"} size={14} /></span>
        <span className="card-time">{item.time}</span>
      </div>
      <div className="card-body">
        <div className="card-main">
          <div className="card-title">{item.title}</div>
          <div className="card-excerpt">{item.excerpt}</div>
        </div>
        {item.hasCover && <div className="card-thumb" style={{ background: coverBg(item.hue) }} />}
      </div>
      <div className="card-foot">
        {itemTags.slice(0, 2).map((t) => <span className="chip" key={t.id}><span className="tdot" style={{ background: t.color }} />{t.name}</span>)}
        <span style={{ flex: 1 }} />
        <span className="card-meta"><Icon name="clock" size={12} />{item.readingTime} 分钟</span>
      </div>
      {item.progress > 0 && item.progress < 1 && <div className="mini-progress"><i style={{ width: Math.round(item.progress * 100) + "%" }} /></div>}
    </article>
  );
}

function ListPane({ selId, newCard }) {
  return (
    <section className="list-pane">
      <div className="list-head">
        <div className="row"><div className="list-title">收件箱</div><button className="icon-btn"><Icon name="sort" size={17} /></button></div>
        <div className="row" style={{ marginTop: -2 }}><span className="list-sub">6 条 · 最新在前</span></div>
        <div className="search"><Icon name="search" size={14} /><span className="ph">搜索标题、正文、标签…</span></div>
      </div>
      <div className="list-scroll">
        {newCard && (
          <div style={{ opacity: newCard.op, transform: `translateY(${newCard.ty}px)`, maxHeight: newCard.mh, overflow: "hidden" }}>
            <ListCard item={CAPTURED} sel={false} />
          </div>
        )}
        {ITEMS.map((it) => <ListCard key={it.id} item={it} sel={it.id === selId} />)}
      </div>
    </section>
  );
}

/* ───────────────────────── Reader pane ───────────────────────── */
function TransBlock({ block, reveal }) {
  if (!block.tr) return null;
  return (
    <div className="trans" lang="zh" style={{ opacity: reveal, maxHeight: reveal * 90, marginTop: reveal < 1 ? -8 : undefined }}>
      <span className="tlabel">译文</span>{block.tr}
    </div>
  );
}
function ArtBlock({ block, highlightOn, bilingual, biReveal }) {
  let content = block.text;
  if (block.hl && highlightOn) {
    const i = block.text.indexOf(block.hl);
    if (i >= 0) content = <>{block.text.slice(0, i)}<mark className="hl">{block.hl}</mark>{block.text.slice(i + block.hl.length)}</>;
  }
  const trans = bilingual ? <TransBlock block={block} reveal={biReveal} /> : null;
  if (block.t === "h2") return <><h2 lang={block.lang}>{block.text}</h2>{trans}</>;
  if (block.t === "quote") return <><blockquote lang={block.lang}>{content}</blockquote>{trans}</>;
  return <><p className={block.t === "lead" ? "lead" : ""} lang={block.lang}>{content}</p>{trans}</>;
}

function ReaderPane({ scrollY, progress, highlightOn, bilingual, biReveal, serif, bilingualBtn, aiBtn }) {
  const a = ARTICLE;
  return (
    <div className="reader">
      <div className="rprogress" style={{ width: (progress * 100).toFixed(1) + "%" }} />
      <div className="reader-bar">
        <div className="crumbs"><span style={{ color: KIND_COLOR[a.kind], display: "inline-flex" }}><Icon name={kindIcon(a.kind)} size={14} /></span><b>{a.source}</b></div>
        <div className="spacer" />
        <button className={"icon-btn" + (bilingualBtn ? " on" : "")}><Icon name="translate" /></button>
        <button className="icon-btn" style={{ fontWeight: 600, fontSize: 15 }}>Aa</button>
        <button className="icon-btn" style={{ color: "var(--star)" }}><Icon name="star-fill" /></button>
        <button className="icon-btn"><Icon name="share" /></button>
        <span style={{ width: 1, height: 22, background: "var(--sep)", margin: "0 4px" }} />
        <button className={"icon-btn" + (aiBtn ? " on" : "")}><Icon name="sparkles" /></button>
      </div>
      <div className="reader-scroll">
        <article className={"article" + (serif ? " serif" : "") + (bilingual ? " bilingual" : "")} lang="en" style={{ transform: `translateY(${-scrollY}px)` }}>
          <div className="art-kicker"><span>{a.source}</span><span className="k-sep">·</span><span className="k-plain">{a.author}</span></div>
          <h1 className="art-title">{a.title}</h1>
          <div className="art-meta">
            <span className="who"><span className="avatar round" style={{ width: 22, height: 22, background: "#5b76b0" }}>M</span>{a.author}</span>
            <span className="m-dot">·</span><span>{a.time}</span><span className="m-dot">·</span><span>约 {a.readingTime} 分钟</span>
          </div>
          <div className="art-cover" style={{ background: coverBg(a.hue) }} />
          <div className="art-body" lang="en">
            {a.blocks.map((b, i) => <ArtBlock key={i} block={b} highlightOn={highlightOn} bilingual={bilingual} biReveal={biReveal} />)}
          </div>
          <div className="art-end"><Icon name="check-circle" size={15} />继续阅读 · 进度 {Math.round(progress * 100)}%</div>
        </article>
      </div>
    </div>
  );
}

/* ───────────────────────── AI panel (right overlay) ───────────────────────── */
function AIPanel({ tx, tab, reveal, chat }) {
  // reveal: {ctx, sum, k1, k2, k3, tags}  (0/1 flags as opacity)
  const r = reveal;
  return (
    <aside className="ai" style={{ position: "absolute", top: 0, right: 0, height: "100%", width: PANE.ai,
        transform: `translateX(${tx}px)`, boxShadow: "-18px 0 50px -22px rgba(0,0,0,.4)" }}>
      <div className="ai-inner">
        <div className="ai-head"><div className="t"><span className="sparkle"><Icon name="sparkles" size={17} /></span>AI 助手</div>
          <button className="icon-btn sm"><Icon name="panel-right" size={16} /></button></div>
        <div className="ai-tabs">
          {AI_TABS.map((t) => <button key={t.id} className={"ai-tab" + (tab === t.id ? " on" : "")}><Icon name={t.icon} size={14} />{t.name}</button>)}
        </div>

        {tab === "summary" && (
          <div className="ai-body">
            <div className="ai-ctx" style={{ opacity: r.ctx }}><span className="ico"><Icon name="globe" size={14} /></span>正在分析 <b>Local-First…</b></div>
            <div className="ai-block" style={{ opacity: r.sum }}>
              <div className="h"><Icon name="doc" size={13} />一句话摘要</div>
              <div className="ai-summary"><p>{SUMMARY.text}</p></div>
            </div>
            <div className="ai-block">
              <div className="h" style={{ opacity: r.k1 }}><Icon name="list" size={13} />关键要点</div>
              <div className="ai-keys">
                {SUMMARY.keys.map((k, i) => <div className="ai-key" key={i} style={{ opacity: r["k" + (i + 1)], transform: `translateY(${(1 - r["k" + (i + 1)]) * 6}px)` }}><span className="n">{i + 1}</span><span>{k}</span></div>)}
              </div>
            </div>
            <div className="ai-block" style={{ opacity: r.tags }}>
              <div className="h"><Icon name="tag" size={13} />建议标签</div>
              <div className="ai-tags">{SUMMARY.tags.map((t) => <span className="chip" key={t}><Icon name="plus" size={11} />{t}</span>)}</div>
            </div>
          </div>
        )}

        {tab === "chat" && (
          <>
            <div className="ai-body">
              <div className="ai-ctx"><span className="ico"><Icon name="link" size={14} /></span>已引用当前文章 · <b>Ink &amp; Switch</b></div>
              <div className="ai-msgs">
                {chat.user && (
                  <div className="msg user" style={{ opacity: chat.userOp, transform: `translateY(${(1 - chat.userOp) * 8}px)` }}>
                    <span className="ava"><Icon name="pencil" size={14} /></span>
                    <div style={{ minWidth: 0 }}><div className="bubble">{CHAT.question}</div></div>
                  </div>
                )}
                {chat.typing && (
                  <div className="msg bot"><span className="ava"><Icon name="sparkles" size={14} /></span>
                    <div className="bubble" style={{ padding: 0 }}><div className="typing"><i /><i /><i /></div></div></div>
                )}
                {chat.bot && (
                  <div className="msg bot" style={{ opacity: chat.botOp, transform: `translateY(${(1 - chat.botOp) * 8}px)` }}>
                    <span className="ava"><Icon name="sparkles" size={14} /></span>
                    <div style={{ minWidth: 0 }}>
                      <div className="bubble">{CHAT.answer.map((l, i) => <p key={i}>{l}</p>)}</div>
                      <div><span className="cite"><Icon name="doc" size={11} />{CHAT.cite}</span></div>
                    </div>
                  </div>
                )}
              </div>
            </div>
            <div className="ai-suggest">{CHAT.suggest.map((s) => <button key={s}>{s}</button>)}</div>
            <div className="ai-compose"><div className="ai-inputwrap"><span className="ta">问点什么,或让 AI 处理这篇内容…</span><button className="send-btn"><Icon name="send" size={16} /></button></div></div>
          </>
        )}
      </div>
    </aside>
  );
}

/* ───────────────────────── Add / capture modal ───────────────────────── */
function AddModal({ pop, typed, showCaret, fetched, fetchReveal }) {
  return (
    <div className="scrim" style={{ opacity: pop }}>
      <div className="modal" style={{ transform: `scale(${0.94 + 0.06 * pop}) translateY(${(1 - pop) * 10}px)`, opacity: pop }}>
        <div className="modal-head"><Icon name="plus" size={18} /><span className="mt">添加内容</span><button className="icon-btn sm"><Icon name="close" size={16} /></button></div>
        <div className="modal-tabs">
          <button className="modal-tab on"><Icon name="link" size={15} />网址</button>
          <button className="modal-tab"><Icon name="paperclip" size={15} />附件</button>
          <button className="modal-tab"><Icon name="markdown" size={15} />Markdown</button>
        </div>
        <div className="modal-body">
          <div className="field">
            <label>网址</label>
            <div className={"url-inp" + (typed ? " focus" : "")}>
              <Icon name="link" size={16} />
              <span className="typed">{typed || <span style={{ color: "var(--text-3)" }}>粘贴文章 / 视频 / 推文链接…</span>}{showCaret && <span className="caret" />}</span>
              <span className="go">抓取</span>
            </div>
          </div>
          {fetched && (
            <div className="fetched" style={{ opacity: fetchReveal, transform: `translateY(${(1 - fetchReveal) * 8}px)` }}>
              <div className="th" style={{ background: coverBg(36) }} />
              <div style={{ minWidth: 0 }}>
                <div className="ft">{CAPTURED.title}</div>
                <div className="fm">wired.com · 自动提取 · 约 7 分钟</div>
                <div className="fx">已抓取正文、标题与首图,排版已清理。保存后即可在本地阅读、翻译与摘要。</div>
              </div>
            </div>
          )}
          <div className="field"><label>标签</label><div className="chips-row">{TAGS.map((t) => <span key={t.id} className="chip"><span className="tdot" style={{ background: t.color }} />{t.name}</span>)}</div></div>
        </div>
        <div className="modal-foot"><span className="sp" /><button className="btn ghost">取消</button><button className="btn primary">保存到本地</button></div>
      </div>
    </div>
  );
}

/* ───────────────────────── small overlays ───────────────────────── */
function Toast({ text, pop }) {
  return <div className="toast" style={{ transform: `translateX(-50%) scale(${0.9 + 0.1 * pop}) translateY(${(1 - pop) * 8}px)`, opacity: pop }}><Icon name="check-circle" size={16} />{text}</div>;
}
function SelectionPopover({ x, y, pop }) {
  return (
    <div className="selpop" style={{ left: x, top: y, opacity: pop, transform: `translate(-50%,-100%) scale(${0.92 + 0.08 * pop})` }}>
      <button className="hl-act"><Icon name="highlighter" size={14} />高亮</button>
      <button><Icon name="translate" size={14} />翻译</button>
      <button><Icon name="chat" size={14} />追问 AI</button>
      <span className="vr" /><button><Icon name="pencil" size={14} />笔记</button>
    </div>
  );
}
function Cursor({ x, y, down }) {
  return (
    <>
      <svg className="cursor" viewBox="0 0 24 24" style={{ left: x, top: y, transform: `translate(-3px,-2px) scale(${down ? 0.86 : 1})` }}>
        <path d="M5 2.5l13.5 8.2-6 1.3 3.4 6.7-2.7 1.4-3.4-6.7-4.8 4z" fill="#fff" stroke="#1c1c20" strokeWidth="1.4" strokeLinejoin="round"/>
      </svg>
    </>
  );
}
function ClickRing({ x, y, p }) {
  const size = 16 + p * 40;
  return <div className="click-ring" style={{ left: x - size / 2, top: y - size / 2, width: size, height: size, opacity: (1 - p) * 0.8 }} />;
}
function Caption({ text, sub, opacity }) {
  return (
    <div className="caption-wrap" style={{ opacity, transform: `translateY(${(1 - opacity) * 14}px)` }}>
      <div className="caption"><span className="ck" /><span className="ctext">{text}</span>{sub && <span className="csub">{sub}</span>}</div>
    </div>
  );
}
function BrandLayer({ opacity, mode }) {
  return (
    <div className="brand-layer" style={{ opacity }}>
      <div className="brand-mark">
        <div className="brand-glyph"><Icon name="book-open" size={54} /></div>
        <div className="brand-word">Reader</div>
      </div>
      <div className="brand-tag">{mode === "outro" ? "数据,始终在你自己手里。" : "本地优先的 Mac 阅读与收藏"}</div>
      {mode === "outro" && <div className="brand-foot">github.com/can4hou6joeng4/ReaderMacApp · macOS 13+</div>}
    </div>
  );
}

Object.assign(window, { Sidebar, ListPane, ReaderPane, AIPanel, AddModal, Toast, SelectionPopover, Cursor, ClickRing, Caption, BrandLayer });
