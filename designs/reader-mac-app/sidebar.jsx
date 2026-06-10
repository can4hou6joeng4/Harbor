// sidebar.jsx — navigation pane (presentational)

function TrafficLights() {
  return (
    <div className="traffic">
      <span className="tl r"></span><span className="tl y"></span><span className="tl g"></span>
    </div>
  );
}

function SideItem({ icon, label, count, sel, onClick, leading, accent, indent }) {
  return (
    <div className={"side-item" + (sel ? " sel" : "") + (indent ? " " + indent : "")} onClick={onClick}>
      {leading}
      {icon && <span className="si-ico" style={accent ? { color: accent } : null}><Icon name={icon} size={16} /></span>}
      <span className="si-label">{label}</span>
      {count > 0 && <span className="count">{fmtCount(count)}</span>}
    </div>
  );
}

function TreeToggle({ open, onClick }) {
  return (
    <span className={"tree-toggle" + (open ? " open" : "")} onClick={(e) => { e.stopPropagation(); onClick(); }}>
      <Icon name="chev" size={12} />
    </span>
  );
}

function Sidebar({ activeView, onSelect, items, onAdd, onManageSubs, theme, onToggleTheme, onSettings }) {
  const [openP, setOpenP] = React.useState({ "p-rss": true, "p-x": false, "p-weibo": false, "p-yt": false });
  const [openF, setOpenF] = React.useState({ "fo-tech": true });

  const dyn = {
    all: items.length,
    unread: items.filter((i) => i.unread).length,
    fav: items.filter((i) => i.fav).length,
  };
  const smartCount = (s) => (dyn[s.id] !== undefined ? dyn[s.id] : s.count);
  const platTotal = (p) => p.feeds.reduce((n, f) => n + f.count, 0);

  return (
    <nav className="sidebar">
      <div className="side-top">
        <TrafficLights />
        <div style={{ flex: 1 }} />
        <button className="icon-btn sm" title="切换亮/暗" onClick={onToggleTheme}>
          <Icon name={theme === "dark" ? "sun" : "moon"} size={16} />
        </button>
        <button className="icon-btn sm" title="添加内容 ⌘N" onClick={onAdd}><Icon name="plus" size={17} /></button>
      </div>

      <div className="side-scroll">
        {/* smart views */}
        <div>
          {SMART.map((s) => (
            <SideItem key={s.id} icon={s.icon} label={s.name} count={smartCount(s)}
                      sel={activeView === s.id} onClick={() => onSelect(s.id)} />
          ))}
        </div>

        {/* subscriptions */}
        <div className="side-section">
          <div className="side-label">
            <span>订阅源</span>
            <button className="icon-btn sm add-mini" style={{ width: 20, height: 20 }} title="管理订阅" onClick={onManageSubs}>
              <Icon name="plus" size={14} />
            </button>
          </div>
          {PLATFORMS.map((p) => (
            <div key={p.id}>
              <SideItem
                icon={p.icon} label={p.name} count={platTotal(p)}
                sel={activeView === p.id} onClick={() => onSelect(p.id)}
                leading={<TreeToggle open={openP[p.id]} onClick={() => setOpenP({ ...openP, [p.id]: !openP[p.id] })} />}
              />
              {openP[p.id] && p.feeds.map((f) => (
                <SideItem key={f.id} label={f.name} count={f.count} indent="indent"
                          sel={activeView === f.id} onClick={() => onSelect(f.id)}
                          leading={<span className="avatar round" style={{ background: f.color }}>{f.mono}</span>} />
              ))}
            </div>
          ))}
        </div>

        {/* folders */}
        <div className="side-section">
          <div className="side-label"><span>目录</span><button className="icon-btn sm add-mini" style={{ width: 20, height: 20 }} title="新建目录"><Icon name="plus" size={14} /></button></div>
          {FOLDERS.map((fo) => (
            <div key={fo.id}>
              <SideItem
                icon="folder" label={fo.name} count={fo.count}
                sel={activeView === fo.id} onClick={() => onSelect(fo.id)}
                leading={fo.children
                  ? <TreeToggle open={openF[fo.id]} onClick={() => setOpenF({ ...openF, [fo.id]: !openF[fo.id] })} />
                  : <span style={{ width: 14, flexShrink: 0 }} />}
              />
              {fo.children && openF[fo.id] && fo.children.map((c) => (
                <SideItem key={c.id} icon="folder" label={c.name} count={c.count} indent="indent"
                          sel={activeView === c.id} onClick={() => onSelect(c.id)}
                          leading={<span style={{ width: 14, flexShrink: 0 }} />} />
              ))}
            </div>
          ))}
        </div>

        {/* tags */}
        <div className="side-section">
          <div className="side-label"><span>标签</span></div>
          {TAGS.map((t) => {
            const n = items.filter((i) => i.tags && i.tags.includes(t.id)).length;
            return (
              <SideItem key={t.id} label={t.name} count={n}
                        sel={activeView === t.id} onClick={() => onSelect(t.id)}
                        leading={<span className="dot" style={{ background: t.color, marginLeft: 3, marginRight: 1 }} />} />
            );
          })}
        </div>
      </div>

      <div style={{ padding: "8px 12px", borderTop: ".5px solid var(--sep)", display: "flex", alignItems: "center", gap: 8 }}>
        <span className="si-ico" style={{ color: "#30c463" }}><Icon name="check-circle" size={15} /></span>
        <span style={{ fontSize: 12, color: "var(--text-3)", flex: 1 }}>数据保存在本地</span>
        <button className="icon-btn sm" title="设置" onClick={onSettings}><Icon name="gear" size={16} /></button>
      </div>
    </nav>
  );
}

Object.assign(window, { Sidebar, TrafficLights, SideItem });
