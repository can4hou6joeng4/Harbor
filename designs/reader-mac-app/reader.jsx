// reader.jsx — reading pane: article render, highlights, typography + selection popovers

const PLAT_FEEDS = {};
PLATFORMS.forEach((p) => p.feeds.forEach((f) => { PLAT_FEEDS[f.id] = f; }));

// wrap highlight substrings in <mark>
function markupText(text, hls) {
  if (!hls || !hls.length) return text;
  const matches = [];
  hls.forEach((h) => { const i = text.indexOf(h.q); if (i >= 0) matches.push({ s: i, e: i + h.q.length, h }); });
  matches.sort((a, b) => a.s - b.s);
  const out = []; let cur = 0, k = 0;
  matches.forEach((m) => {
    if (m.s < cur) return;
    if (m.s > cur) out.push(text.slice(cur, m.s));
    out.push(
      <mark key={k++} className={"hl" + (m.h.note ? " note" : "")} title={m.h.note || "高亮"}>{text.slice(m.s, m.e)}</mark>
    );
    cur = m.e;
  });
  if (cur < text.length) out.push(text.slice(cur));
  return out;
}

function TransBlock({ block }) {
  if (!block.tr) return null;
  return (
    <div className="trans" lang={block.lang === "en" ? "zh" : "en"}>
      <span className="tlabel">{block.lang === "en" ? "译文" : "Translation"}</span>{block.tr}
    </div>
  );
}

function Block({ block, hls }) {
  if (block.t === "img") {
    return (<><div className="art-img" style={{ background: coverBg(block.hue) }} /><div className="art-cap">{block.cap}</div></>);
  }
  const content = markupText(block.text, hls);
  if (block.t === "h2") return (<><h2 lang={block.lang}>{block.text}</h2>{block.tr ? <TransBlock block={block} /> : null}</>);
  if (block.t === "quote") return (<><blockquote lang={block.lang}>{content}</blockquote><TransBlock block={block} /></>);
  const cls = block.t === "lead" ? "lead" : "";
  return (<><p className={cls} lang={block.lang}>{content}</p><TransBlock block={block} /></>);
}

function Stepper({ value, onDec, onInc, display }) {
  return (
    <div className="stepper">
      <button onClick={onDec}><Icon name="minus" size={13} /></button>
      <span className="v">{display}</span>
      <button onClick={onInc}><Icon name="plus" size={13} /></button>
    </div>
  );
}

function TypographyPopover({ s, set, theme, onSetTheme }) {
  return (
    <div className="pop typo-pop fade-in">
      <div className="typo-row">
        <span className="lab">字体</span>
        <div className="seg">
          <button className={s.serif ? "on" : ""} onClick={() => set.serif(true)} style={{ fontFamily: "var(--serif)" }}>衬线</button>
          <button className={!s.serif ? "on" : ""} onClick={() => set.serif(false)}>无衬线</button>
        </div>
      </div>
      <div className="typo-row">
        <span className="lab">字号</span>
        <Stepper display={s.font + "px"} onDec={() => set.font(Math.max(15, s.font - 1))} onInc={() => set.font(Math.min(23, s.font + 1))} />
      </div>
      <div className="typo-row">
        <span className="lab">行距</span>
        <Stepper display={s.line.toFixed(2)} onDec={() => set.line(Math.max(1.5, +(s.line - 0.08).toFixed(2)))} onInc={() => set.line(Math.min(2.2, +(s.line + 0.08).toFixed(2)))} />
      </div>
      <div className="typo-row">
        <span className="lab">栏宽</span>
        <Stepper display={s.width} onDec={() => set.width(Math.max(560, s.width - 40))} onInc={() => set.width(Math.min(860, s.width + 40))} />
      </div>
      <div className="typo-row">
        <span className="lab">阅读主题</span>
        <div className="seg">
          <button className={theme === "light" ? "on" : ""} onClick={() => onSetTheme("light")}>日</button>
          <button className={theme === "dark" ? "on" : ""} onClick={() => onSetTheme("dark")}>夜</button>
        </div>
      </div>
    </div>
  );
}

function SelectionPopover({ sel, onHighlight, onTranslate, onAsk, onCopy, onNote }) {
  return (
    <div className="selpop" style={{ left: sel.x, top: sel.y }} onMouseDown={(e) => e.preventDefault()}>
      <button className="hl-act" onClick={onHighlight}><Icon name="highlighter" size={14} />高亮</button>
      <button onClick={onTranslate}><Icon name="translate" size={14} />翻译</button>
      <button onClick={onAsk}><Icon name="chat" size={14} />追问 AI</button>
      <span className="vr" />
      <button onClick={onNote}><Icon name="pencil" size={14} />笔记</button>
      <button onClick={onCopy}><Icon name="copy" size={14} />复制</button>
    </div>
  );
}

function Reader({ item, theme, onSetTheme, s, set, bilingual, onSetBilingual,
                  typoOpen, onTypoToggle, aiOpen, onToggleAI, onFav, onProgress,
                  onHighlight, onAskAI }) {
  const scrollRef = React.useRef(null);
  const rootRef = React.useRef(null);
  const [sel, setSel] = React.useState(null);
  const [note, setNote] = React.useState(null);

  // restore + persist scroll position per item
  React.useEffect(() => {
    setSel(null); setNote(null);
    const el = scrollRef.current; if (!el || !item) return;
    const saved = +(localStorage.getItem("rpos:" + item.id) || 0);
    requestAnimationFrame(() => { el.scrollTop = saved; });
  }, [item && item.id]);

  if (!item) {
    return (
      <div className="reader">
        <div className="empty-reader"><Icon name="stack" size={46} /><div>从左侧选择一篇内容开始阅读</div></div>
      </div>
    );
  }

  const onScroll = () => {
    const el = scrollRef.current; if (!el) return;
    const max = el.scrollHeight - el.clientHeight;
    const pct = max > 0 ? Math.min(1, el.scrollTop / max) : 0;
    onProgress(item.id, pct);
    localStorage.setItem("rpos:" + item.id, String(el.scrollTop));
    if (sel) setSel(null);
  };

  const onMouseUp = () => {
    const selObj = window.getSelection();
    const text = selObj && selObj.toString().trim();
    if (!text || text.length < 2) { setSel(null); return; }
    const rect = selObj.getRangeAt(0).getBoundingClientRect();
    const box = rootRef.current.getBoundingClientRect();
    setSel({ text, x: rect.left + rect.width / 2 - box.left, y: rect.top - box.top - 9 });
  };

  const isVideo = item.type === "youtube" || item.type === "video";
  const feed = item.feedId ? PLAT_FEEDS[item.feedId] : null;
  const closeSel = () => { setSel(null); window.getSelection().removeAllRanges(); };

  return (
    <div className="reader" ref={rootRef}>
      <div className="rprogress" style={{ width: (item.progress * 100).toFixed(1) + "%" }} />

      <div className="reader-bar">
        <div className="crumbs">
          <span style={{ color: KIND_COLOR[item.kind], display: "inline-flex" }}><Icon name={kindIcon(item.kind)} size={14} /></span>
          <b>{item.source}</b>
        </div>
        <div className="spacer" />
        <button className={"icon-btn" + (bilingual ? " on" : "")} title="双语对照" onClick={() => onSetBilingual(!bilingual)}><Icon name="translate" /></button>
        <button className={"icon-btn" + (typoOpen ? " on" : "")} title="排版" onClick={onTypoToggle} style={{ fontWeight: 600, fontSize: 15 }}>Aa</button>
        <button className="icon-btn" title={item.fav ? "取消收藏" : "收藏"} style={{ color: item.fav ? "var(--star)" : undefined }} onClick={() => onFav(item.id)}><Icon name={item.fav ? "star-fill" : "star"} /></button>
        <button className="icon-btn" title="分享"><Icon name="share" /></button>
        <button className="icon-btn" title="更多"><Icon name="ellipsis" /></button>
        <span style={{ width: 1, height: 22, background: "var(--sep)", margin: "0 4px" }} />
        <button className={"icon-btn" + (aiOpen ? " on" : "")} title="AI 助手" onClick={onToggleAI}><Icon name="sparkles" /></button>
      </div>

      {typoOpen && <TypographyPopover s={s} set={set} theme={theme} onSetTheme={onSetTheme} />}

      <div className="reader-scroll" ref={scrollRef} onScroll={onScroll} onMouseUp={onMouseUp}>
        <article className={"article" + (s.serif ? " serif" : "") + (bilingual ? " bilingual" : "")}
                 lang={item.lang} style={{ "--reading-size": s.font + "px", "--reading-lh": s.line, "--reading-width": s.width + "px" }}>
          <div className="art-kicker">
            <span>{item.source}</span>
            {item.author && <><span className="k-sep">·</span><span className="k-plain">{item.author}</span></>}
          </div>
          <h1 className="art-title">{item.title}</h1>
          <div className="art-meta">
            <span className="who">
              <span className="avatar round" style={{ width: 22, height: 22, background: feed ? feed.color : "var(--accent)" }}>{(item.author || "?").slice(0, 1)}</span>
              {item.author}
            </span>
            <span className="m-dot">·</span><span>{item.time}</span>
            <span className="m-dot">·</span>
            <span>{item.duration ? "时长 " + item.duration : "约 " + item.readingTime + " 分钟"}</span>
          </div>

          {/* hero */}
          {item.type === "pdf" ? (
            <div className="pdf-page" style={{ margin: "26px 0 30px" }}>
              <h3>{item.title.replace(/\.pdf$/, "")}</h3>
              <p><b>Abstract.</b> The dominant sequence transduction models are based on complex recurrent or convolutional neural networks…</p>
              <p style={{ color: "#888" }}>— 第 1 页,共 15 页 · 已提取全文 ·</p>
            </div>
          ) : isVideo ? (
            <div className="att-hero video" style={{ background: coverBg(item.hue), margin: "26px 0 30px" }}>
              <span className="vplay"><Icon name="play" size={26} /></span>
              <span className="dur" style={{ position: "absolute", right: 12, bottom: 12, background: "rgba(0,0,0,.7)", color: "#fff", fontSize: 12, padding: "2px 7px", borderRadius: 6 }}>{item.duration}</span>
            </div>
          ) : item.hasCover ? (
            <div className="art-cover" style={{ background: coverBg(item.hue) }} />
          ) : null}

          <div className="art-body" lang={item.lang}>
            {item.body.map((b, i) => <Block key={i} block={b} hls={item.highlights} />)}
          </div>

          <div className="art-end"><Icon name="check-circle" size={15} />{item.progress >= 0.98 ? "已读完" : "继续阅读 · 进度 " + Math.round(item.progress * 100) + "%"}</div>
        </article>
      </div>

      {sel && (
        <SelectionPopover sel={sel}
          onHighlight={() => { onHighlight(item.id, sel.text, ""); closeSel(); }}
          onTranslate={() => { onAskAI("翻译这段:“" + sel.text + "”", "translate"); closeSel(); }}
          onAsk={() => { onAskAI("关于这段的疑问:“" + sel.text + "”", "chat"); closeSel(); }}
          onCopy={() => { navigator.clipboard && navigator.clipboard.writeText(sel.text); closeSel(); }}
          onNote={() => { setNote({ text: sel.text, x: sel.x, y: sel.y, val: "" }); setSel(null); }}
        />
      )}

      {note && (
        <div className="pop notes-pop fade-in" style={{ left: Math.max(12, note.x - 160), top: note.y + 14 }}>
          <div className="quote-pre">{note.text.length > 90 ? note.text.slice(0, 90) + "…" : note.text}</div>
          <textarea autoFocus placeholder="写下你的笔记…" value={note.val} onChange={(e) => setNote({ ...note, val: e.target.value })} />
          <div style={{ display: "flex", gap: 8, marginTop: 10, justifyContent: "flex-end" }}>
            <button className="btn ghost" onClick={() => setNote(null)}>取消</button>
            <button className="btn primary" onClick={() => { onHighlight(item.id, note.text, note.val); setNote(null); window.getSelection().removeAllRanges(); }}>保存高亮 + 笔记</button>
          </div>
        </div>
      )}
    </div>
  );
}

Object.assign(window, { Reader, Block, markupText, TypographyPopover, SelectionPopover, PLAT_FEEDS });
