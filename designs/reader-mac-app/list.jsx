// list.jsx — middle column: list header + article cards (presentational)

const KIND_COLOR = {
  web: "var(--text-3)", rss: "#e0533d", x: "var(--text-2)", weibo: "#e6162d",
  youtube: "#cf2b2b", pdf: "#d8443a", markdown: "var(--text-3)", image: "#c98a2b", video: "#cf2b2b",
};
const TAG_BY_ID = Object.fromEntries(TAGS.map((t) => [t.id, t]));

function ListItem({ item, sel, onClick, onFav }) {
  const isVideo = item.type === "youtube" || item.type === "video";
  const itemTags = (item.tags || []).map((id) => TAG_BY_ID[id]).filter(Boolean);
  return (
    <article className={"card" + (sel ? " sel" : "") + (item.unread ? "" : " read")} onClick={onClick}>
      <div className="card-top">
        {item.unread && <span className="unread-dot" />}
        <div className="card-src">
          <span style={{ color: KIND_COLOR[item.kind], display: "inline-flex", flexShrink: 0 }}>
            <Icon name={kindIcon(item.kind)} size={13} />
          </span>
          <span className="src-name">{item.source}</span>
        </div>
        <button className="icon-btn sm" style={{ width: 22, height: 22, color: item.fav ? "var(--star)" : "var(--text-4)" }}
                onClick={(e) => { e.stopPropagation(); onFav(item.id); }} title={item.fav ? "取消收藏" : "收藏"}>
          <Icon name={item.fav ? "star-fill" : "star"} size={14} />
        </button>
        <span className="card-time">{item.time}</span>
      </div>

      <div className="card-body">
        <div className="card-main">
          <div className="card-title">{item.title}</div>
          <div className="card-excerpt">{item.excerpt}</div>
        </div>
        {item.hasCover && (
          <div className="card-thumb" style={{ background: coverBg(item.hue) }}>
            {isVideo && <span className="play"><Icon name="play" size={22} /></span>}
            {item.duration && <span className="dur">{item.duration}</span>}
          </div>
        )}
      </div>

      <div className="card-foot">
        {itemTags.slice(0, 2).map((t) => (
          <span className="chip" key={t.id}><span className="tdot" style={{ background: t.color }} />{t.name}</span>
        ))}
        <span style={{ flex: 1 }} />
        <span className="card-meta">
          <Icon name={isVideo ? "play" : "clock"} size={12} />
          {item.duration ? item.duration : item.readingTime + " 分钟"}
        </span>
      </div>

      {item.progress > 0 && item.progress < 1 && (
        <div className="mini-progress"><i style={{ width: Math.round(item.progress * 100) + "%" }} /></div>
      )}
    </article>
  );
}

const SORTS = [
  { id: "new", label: "最新在前" },
  { id: "old", label: "最早在前" },
  { id: "unread", label: "未读优先" },
];

function ListPane({ title, subtitle, items, selectedId, onSelect, query, onQuery, sort, onSort, onFav }) {
  const cur = SORTS.find((s) => s.id === sort) || SORTS[0];
  const cycleSort = () => { const i = SORTS.findIndex((s) => s.id === sort); onSort(SORTS[(i + 1) % SORTS.length].id); };
  return (
    <section className="list-pane">
      <div className="list-head">
        <div className="row">
          <div className="list-title">{title}</div>
          <button className="icon-btn" title={"排序:" + cur.label} onClick={cycleSort}><Icon name="sort" size={17} /></button>
        </div>
        <div className="row" style={{ marginTop: -2 }}>
          <span className="list-sub">{subtitle} · {cur.label}</span>
        </div>
        <div className="search">
          <Icon name="search" size={14} />
          <input value={query} onChange={(e) => onQuery(e.target.value)} placeholder="搜索标题、正文、标签…" />
          {query && <button className="icon-btn sm" style={{ width: 20, height: 20 }} onClick={() => onQuery("")}><Icon name="close" size={13} /></button>}
        </div>
      </div>

      <div className="list-scroll">
        {items.length === 0 && <div className="list-empty">没有匹配的内容</div>}
        {items.map((it) => (
          <ListItem key={it.id} item={it} sel={it.id === selectedId} onClick={() => onSelect(it.id)} onFav={onFav} />
        ))}
      </div>
    </section>
  );
}

Object.assign(window, { ListPane, ListItem, SORTS, TAG_BY_ID, KIND_COLOR });
