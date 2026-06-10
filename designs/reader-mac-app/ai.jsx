// ai.jsx — right AI panel: 摘要 / 翻译 / 对话 / 二创 (presentational)

const AI_TABS = [
  { id: "summary",   name: "摘要", icon: "doc" },
  { id: "translate", name: "翻译", icon: "translate" },
  { id: "chat",      name: "对话", icon: "chat" },
  { id: "remix",     name: "二创", icon: "wand" },
];

function genRemix(type, item, srcItems) {
  const keys = (item.summary && item.summary.keys) || [];
  const titles = srcItems.map((i) => i.title);
  if (type === "rx-thread") {
    return ["1/ " + item.title + " —— 一篇值得记下来的文章。",
      "2/ " + (keys[0] || ""), "3/ " + (keys[1] || ""), "4/ " + (keys[2] || ""),
      "5/ 完整笔记已存进我的本地 Reader,数据全在自己手里。"].filter(Boolean).join("\n\n");
  }
  if (type === "rx-weekly") {
    return "## 本周阅读回顾\n\n本周共读 " + srcItems.length + " 篇:\n" +
      titles.map((t) => "- " + t).join("\n") + "\n\n一句话收获:" + (keys[0] || "持续把好内容沉淀到本地。");
  }
  if (type === "rx-cross") {
    return "## 综述:关于「本地优先」的几篇对读\n\n综合 " + titles.length + " 篇来源,可以看到一条共同线索——\n\n" +
      titles.map((t, i) => (i + 1) + ". 《" + t + "》") .join("\n") +
      "\n\n它们都指向同一个判断:" + (keys[0] || "把数据的所有权还给用户") + "。";
  }
  // rx-note
  return "# " + item.title + " · 读书笔记\n\n## 要点\n" + keys.map((k) => "- " + k).join("\n") +
    (item.highlights && item.highlights.length ? "\n\n## 我的高亮\n" + item.highlights.map((h) => "> " + h.q + (h.note ? "\n  注:" + h.note : "")).join("\n") : "");
}

function AIPanel({ item, tab, onTab, messages, sending, onSend, onClose, items, bilingual, onSetBilingual, onToast }) {
  const [input, setInput] = React.useState("");
  const [focus, setFocus] = React.useState(false);
  const [dir, setDir] = React.useState(item && item.lang === "en" ? "en2zh" : "zh2en");
  const [rx, setRx] = React.useState(null);
  const [rxSrc, setRxSrc] = React.useState(() => new Set(item ? [item.id] : []));
  const [rxOut, setRxOut] = React.useState(null);
  const bodyRef = React.useRef(null);

  React.useEffect(() => { if (tab === "chat" && bodyRef.current) bodyRef.current.scrollTop = bodyRef.current.scrollHeight; }, [messages, sending, tab]);
  React.useEffect(() => { setRxSrc(new Set(item ? [item.id] : [])); setRxOut(null); setRx(null); }, [item && item.id]);

  const send = () => { const t = input.trim(); if (!t) return; onSend(t); setInput(""); };
  const onKey = (e) => { if (e.key === "Enter" && !e.shiftKey) { e.preventDefault(); send(); } };

  const sum = item && item.summary;
  const recent = items.slice(0, 7);
  const toggleSrc = (id) => { const n = new Set(rxSrc); n.has(id) ? n.delete(id) : n.add(id); setRxSrc(n); setRxOut(null); };
  const doGen = (type) => { setRx(type); setRxOut(genRemix(type, item, items.filter((i) => rxSrc.has(i.id)))); };

  return (
    <aside className="ai">
      <div className="ai-head">
        <div className="t"><span className="sparkle"><Icon name="sparkles" size={17} /></span>AI 助手</div>
        <button className="icon-btn sm" title="收起" onClick={onClose}><Icon name="panel-right" size={16} /></button>
      </div>

      <div className="ai-tabs">
        {AI_TABS.map((t) => (
          <button key={t.id} className={"ai-tab" + (tab === t.id ? " on" : "")} onClick={() => onTab(t.id)}>
            <Icon name={t.icon} size={14} />{t.name}
          </button>
        ))}
      </div>

      {!item && <div className="ai-body"><div className="list-empty">选择一篇内容后,AI 才能帮上忙</div></div>}

      {item && tab === "summary" && (
        <div className="ai-body">
          <div className="ai-ctx"><span className="ico"><Icon name={kindIcon(item.kind)} size={14} /></span>正在分析 <b>{item.title.length > 16 ? item.title.slice(0, 16) + "…" : item.title}</b></div>
          <div className="ai-block">
            <div className="h"><Icon name="doc" size={13} />一句话摘要</div>
            <div className="ai-summary">{sum.text.map((p, i) => <p key={i}>{p}</p>)}</div>
          </div>
          <div className="ai-block">
            <div className="h"><Icon name="list" size={13} />关键要点</div>
            <div className="ai-keys">{sum.keys.map((k, i) => <div className="ai-key" key={i}><span className="n">{i + 1}</span><span>{k}</span></div>)}</div>
          </div>
          <div className="ai-block">
            <div className="h"><Icon name="tag" size={13} />建议标签</div>
            <div className="ai-tags">{sum.tagSuggest.map((t) => <span className="chip" key={t} onClick={() => onToast("已添加标签「" + t + "」")}><Icon name="plus" size={11} />{t}</span>)}</div>
          </div>
          <div style={{ display: "flex", gap: 8 }}>
            <button className="btn ghost" style={{ flex: 1 }} onClick={() => onToast("摘要已复制")}><Icon name="copy" size={14} style={{ marginRight: 6, verticalAlign: "-2px" }} />复制</button>
            <button className="btn ghost" style={{ flex: 1 }} onClick={() => onToast("已存为笔记")}><Icon name="bookmark" size={14} style={{ marginRight: 6, verticalAlign: "-2px" }} />存为笔记</button>
          </div>
        </div>
      )}

      {item && tab === "translate" && (
        <div className="ai-body">
          <div className="ai-ctx" style={{ justifyContent: "space-between" }}>
            <span>翻译方向</span>
            <div className="seg">
              <button className={dir === "en2zh" ? "on" : ""} onClick={() => setDir("en2zh")}>英 → 中</button>
              <button className={dir === "zh2en" ? "on" : ""} onClick={() => setDir("zh2en")}>中 → 英</button>
            </div>
          </div>
          <div className="ai-block">
            <div className="h"><Icon name="translate" size={13} />全文翻译</div>
            <div className="ai-summary">
              {item.body.filter((b) => b.t !== "img").slice(0, 6).map((b, i) => (
                <p key={i}>{dir === "en2zh" ? (b.lang === "en" ? b.tr : b.text) : (b.lang === "zh" ? b.tr : b.text)}</p>
              ))}
            </div>
          </div>
          <button className={"btn " + (bilingual ? "ghost" : "primary")} onClick={() => { onSetBilingual(!bilingual); onToast(bilingual ? "已关闭双语对照" : "已在阅读区开启双语对照"); }}>
            <Icon name="eye" size={14} style={{ marginRight: 6, verticalAlign: "-2px" }} />{bilingual ? "关闭双语对照" : "在阅读区开启双语对照"}
          </button>
        </div>
      )}

      {item && tab === "chat" && (
        <>
          <div className="ai-body" ref={bodyRef}>
            <div className="ai-ctx"><span className="ico"><Icon name="link" size={14} /></span>已引用当前文章 · <b>{item.source}</b></div>
            <div className="ai-msgs">
              {messages.map((m, i) => (
                <div className={"msg " + (m.role === "user" ? "user" : "bot")} key={i}>
                  <span className="ava"><Icon name={m.role === "user" ? "pencil" : "sparkles"} size={14} /></span>
                  <div style={{ minWidth: 0 }}>
                    <div className="bubble">{m.text.split("\n").map((line, j) => <p key={j}>{line}</p>)}</div>
                    {m.cites && m.cites.length > 0 && <div>{m.cites.map((c, j) => <span className="cite" key={j}><Icon name="doc" size={11} />{c}</span>)}</div>}
                  </div>
                </div>
              ))}
              {sending && <div className="msg bot"><span className="ava"><Icon name="sparkles" size={14} /></span><div className="bubble" style={{ padding: 0 }}><div className="typing"><i /><i /><i /></div></div></div>}
            </div>
          </div>
          <div className="ai-suggest">{CHAT_SUGGEST.map((s) => <button key={s} onClick={() => onSend(s)}>{s}</button>)}</div>
          <div className="ai-compose">
            <div className={"ai-inputwrap" + (focus ? " focus" : "")}>
              <textarea rows={1} placeholder="问点什么,或让 AI 处理这篇内容…" value={input}
                        onChange={(e) => setInput(e.target.value)} onKeyDown={onKey}
                        onFocus={() => setFocus(true)} onBlur={() => setFocus(false)} />
              <button className="send-btn" disabled={!input.trim()} onClick={send}><Icon name="send" size={16} /></button>
            </div>
          </div>
        </>
      )}

      {item && tab === "remix" && (
        <div className="ai-body">
          <div className="ai-block">
            <div className="h"><Icon name="wand" size={13} />选择创作方式</div>
            {REMIX.map((r) => (
              <div className={"remix-opt"} key={r.id} onClick={() => doGen(r.id)} style={rx === r.id ? { background: "var(--accent-soft)" } : null}>
                <span className="ico"><Icon name={r.icon} size={17} /></span>
                <div style={{ flex: 1 }}><div className="tt">{r.title}</div><div className="dd">{r.desc}</div></div>
                <Icon name="chev" size={14} style={{ color: "var(--text-3)" }} />
              </div>
            ))}
          </div>
          <div className="ai-block">
            <div className="h"><Icon name="stack" size={13} />创作来源 · 已选 {rxSrc.size}</div>
            <div className="src-pills">
              {recent.map((i) => (
                <span className="chip" key={i.id} onClick={() => toggleSrc(i.id)}
                      style={rxSrc.has(i.id) ? { background: "var(--accent)", color: "#fff" } : null}>
                  {rxSrc.has(i.id) && <Icon name="check" size={11} />}{i.title.length > 12 ? i.title.slice(0, 12) + "…" : i.title}
                </span>
              ))}
            </div>
          </div>
          {rxOut && (
            <div className="ai-block fade-in">
              <div className="h"><Icon name="sparkles" size={13} />生成草稿</div>
              <div className="remix-card" style={{ whiteSpace: "pre-wrap", fontSize: 13, lineHeight: 1.65 }}>{rxOut}</div>
              <div style={{ display: "flex", gap: 8, marginTop: 10 }}>
                <button className="btn ghost" style={{ flex: 1 }} onClick={() => onToast("草稿已复制")}>复制</button>
                <button className="btn primary" style={{ flex: 1 }} onClick={() => onToast("已存为新笔记")}>存为笔记</button>
              </div>
            </div>
          )}
        </div>
      )}
    </aside>
  );
}

Object.assign(window, { AIPanel, AI_TABS, genRemix });
