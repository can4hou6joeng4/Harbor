// promo-app.jsx — timeline controller: derive state + camera + cursor from time, render, mount.

const { useTime } = window;

/* ── helpers ── */
const seg = (t, a, b) => clamp((t - a) / (b - a), 0, 1);
const ease = Easing.easeInOutCubic;
const eo = Easing.easeOutCubic;
// keyframe sampler: pts = [[t,val],...]
function kf(t, pts, e = ease) {
  return interpolate(pts.map((p) => p[0]), pts.map((p) => p[1]), e)(t);
}
// caption / fade envelope
const fade = (t, a, b, fi = 0.45, fo = 0.5) => Math.min(seg(t, a, a + fi), 1 - seg(t, b - fo, b));

/* ── camera keyframes: scale + center(canvas coords) ── */
const CAM_S  = [[0,1.12],[T.brand[1],1.0],[4.7,1.5],[5.5,1.2],[9.6,1.27],[10.35,1.05],[11.5,1.05],
                [12.0,1.5],[15.3,1.5],[15.9,1.32],[19.4,1.5],[20.7,1.5],[21.0,1.28],[24.2,1.28],
                [24.6,1.2],[27.7,1.2],[28.0,1.22],[32.2,1.22],[32.7,1.0],[37,1.0]];
const CAM_X  = [[0,960],[T.brand[1],960],[4.7,470],[5.5,960],[9.6,960],[10.35,900],[11.5,900],
                [12.0,498],[15.3,498],[15.9,1230],[19.4,1235],[20.7,1235],[21.0,1230],[24.2,1230],
                [24.6,1440],[27.7,1480],[28.0,1500],[32.2,1500],[32.7,960],[37,960]];
const CAM_Y  = [[0,540],[T.brand[1],540],[4.7,330],[5.5,505],[9.6,520],[10.35,560],[11.5,560],
                [12.0,540],[15.3,575],[15.9,540],[19.4,470],[20.7,470],[21.0,545],[24.2,560],
                [24.6,505],[27.7,560],[28.0,560],[32.2,560],[32.7,540],[37,540]];

/* ── cursor: show windows + path (canvas coords) + click times ── */
const CUR_SHOW = [[4.3,10.45],[18.9,20.7],[27.35,28.15]];
const CUR_X = [[4.3,1000],[4.95,294],[5.5,760],[7.2,760],[7.45,1208],[8.0,1208],[9.7,1182],[10.1,1182],
               [18.9,1120],[19.6,1300],[20.1,1176],[20.5,1176],
               [27.35,1520],[27.85,1716],[28.1,1716]];
const CUR_Y = [[4.3,650],[4.95,84],[5.5,452],[7.2,452],[7.45,452],[8.0,452],[9.7,742],[10.1,742],
               [18.9,470],[19.6,470],[20.1,430],[20.5,430],
               [27.35,300],[27.85,140],[28.1,140]];
const CLICKS = [5.0, 7.45, 9.95, 20.2, 27.9];
const curShown = (t) => CUR_SHOW.some(([a, b]) => t >= a && t <= b);

/* selection popover + highlight-button canvas anchor (tuned to the article) */
const SEL = { x: 1232, y: 480 };

const FULL_URL = "wired.com/story/own-your-data";

function applyCam(s, cx, cy, px, py) {
  const tx = CANVAS.w / 2 - s * cx, ty = CANVAS.h / 2 - s * cy;
  return [tx + s * px, ty + s * py];
}

function Promo() {
  const t = useTime();

  /* theme + veil */
  const dark = t >= T.darkFlip;
  const theme = dark ? "dark" : "light";
  const veilOp = t < T.veil[0] || t > T.veil[1] ? 0 : (t < T.darkFlip ? seg(t, T.veil[0], T.darkFlip) : 1 - seg(t, T.darkFlip, T.veil[1]));

  /* camera */
  const s = kf(t, CAM_S), cx = kf(t, CAM_X), cy = kf(t, CAM_Y);
  const camTransform = `translate(${(CANVAS.w / 2 - s * cx).toFixed(2)}px, ${(CANVAS.h / 2 - s * cy).toFixed(2)}px) scale(${s.toFixed(4)})`;

  /* brand layers */
  const brandIntro = 1 - seg(t, 2.7, 3.9);
  const brandOutro = seg(t, T.brandIn, T.brandIn + 0.9);

  /* ── capture state ── */
  const modalPop = (t < T.capture[0] || t > T.cModalOut[1] + 0.05) ? 0
    : (t < T.cModalIn[1] ? seg(t, T.cModalIn[0], T.cModalIn[1]) : 1 - seg(t, T.cModalOut[0], T.cModalOut[1]));
  const typedN = Math.round(seg(t, T.cTypeStart, T.cTypeEnd) * FULL_URL.length);
  const typed = t >= T.cTypeStart ? FULL_URL.slice(0, typedN) : "";
  const showCaret = t >= T.cTypeStart && t < T.cFetch && Math.floor(t * 2) % 2 === 0;
  const fetched = t >= T.cFetch;
  const fetchReveal = seg(t, T.cFetchIn[0], T.cFetchIn[1]);
  const toastPop = (t < T.cToast[0] || t > T.cToast[1] + 0.4) ? 0 : Math.min(seg(t, T.cToast[0], T.cToast[0] + 0.3), 1 - seg(t, T.cToast[1], T.cToast[1] + 0.4));
  // new captured card appears after save
  const newCardP = seg(t, T.cNewCard, T.cNewCard + 0.7);
  const newCard = t >= T.cNewCard ? { op: newCardP, ty: (1 - newCardP) * -10, mh: 30 + newCardP * 170 } : null;
  const addPulse = t >= 4.85 && t <= 5.25;

  /* ── reading state ── */
  let scrollY = 0;
  if (t >= T.rScroll[0]) scrollY = kf(t, [[T.rScroll[0], 0], [T.rScroll[1], 312], [T.rScroll2[0], 312], [T.rScroll2[1], 470]], eo);
  const highlightOn = t >= T.rHl;
  const bilingual = t >= T.rBiToggle;
  const biReveal = seg(t, T.rBiIn[0], T.rBiIn[1]);
  const bilingualBtn = bilingual;
  const readProgress = clamp(0.30 + scrollY / 760, 0.30, 0.96);
  const aiOpen = t >= T.aPanelIn[0];
  const readingProgress = aiOpen ? 0.74 : (t >= T.read[0] ? readProgress : 0.42);
  // selection popover
  const selPop = (t < T.rSelIn[0] || t > T.rHl + 0.15) ? 0 : Math.min(seg(t, T.rSelIn[0], T.rSelIn[1]), 1 - seg(t, T.rHl, T.rHl + 0.15));

  /* ── AI state ── */
  const aiTab = t >= T.aChatTab ? "chat" : "summary";
  const aiTx = (1 - seg(t, T.aPanelIn[0], T.aPanelIn[1])) * PANE.ai;   // slide-in from right
  const reveal = {
    ctx: seg(t, T.aSumCtx, T.aSumCtx + 0.3), sum: seg(t, T.aSum, T.aSum + 0.35),
    k1: seg(t, T.aKey1, T.aKey1 + 0.3), k2: seg(t, T.aKey2, T.aKey2 + 0.3),
    k3: seg(t, T.aKey3, T.aKey3 + 0.3), tags: seg(t, T.aTags, T.aTags + 0.3),
  };
  const chat = {
    user: t >= T.aUser, userOp: seg(t, T.aUser, T.aUser + 0.3),
    typing: t >= T.aTyping[0] && t < T.aTyping[1],
    bot: t >= T.aBot, botOp: seg(t, T.aBot, T.aBot + 0.4),
  };

  /* ── cursor + clicks ── */
  const cShown = curShown(t);
  const curX = kf(t, CUR_X, eo), curY = kf(t, CUR_Y, eo);
  const [csx, csy] = applyCam(s, cx, cy, curX, curY);
  const activeClick = CLICKS.find((c) => t >= c && t < c + 0.4);
  const curDown = activeClick != null && t < activeClick + 0.13;
  let ring = null;
  if (activeClick != null) { const [rx, ry] = applyCam(s, cx, cy, kf(activeClick, CUR_X, eo), kf(activeClick, CUR_Y, eo)); ring = { x: rx, y: ry, p: seg(t, activeClick, activeClick + 0.4) }; }

  /* selection popover screen pos */
  const [selSx, selSy] = applyCam(s, cx, cy, SEL.x, SEL.y);

  /* active caption */
  let cap = null;
  for (const c of CAPTIONS) { const o = fade(t, c.start, c.end); if (o > 0.01) { cap = { ...c, opacity: o }; break; } }

  const label = "t=" + t.toFixed(1) + "s";

  return (
    <div className={"r-scope stage-root"} data-theme={theme} data-screen-label={label}>
      {/* world (zoomed by camera) */}
      <div className="cam" style={{ transform: camTransform }}>
        <div className="desktop" />
        <div className="pwindow" style={{ left: WIN.x, top: WIN.y, width: WIN.w, height: WIN.h }}>
          <Sidebar theme={theme} addPulse={addPulse} />
          <ListPane selId="a1" newCard={newCard} />
          <ReaderPane scrollY={scrollY} progress={readingProgress} highlightOn={highlightOn}
                      bilingual={bilingual} biReveal={biReveal} serif={false} bilingualBtn={bilingualBtn} aiBtn={aiOpen} />
          {aiOpen && <AIPanel tx={aiTx} tab={aiTab} reveal={reveal} chat={chat} />}
          {modalPop > 0 && <AddModal pop={modalPop} typed={typed} showCaret={showCaret} fetched={fetched} fetchReveal={fetchReveal} />}
          {toastPop > 0 && <Toast text="已保存到本地" pop={toastPop} />}
        </div>
      </div>

      {/* screen-space overlays (not zoomed) */}
      {selPop > 0 && <SelectionPopover x={selSx} y={selSy} pop={selPop} />}
      <div className="vignette" />
      {veilOp > 0 && <div className="veil" style={{ opacity: veilOp }} />}
      {ring && ring.p < 1 && cShown && <ClickRing x={ring.x} y={ring.y} p={ring.p} />}
      {cShown && <Cursor x={csx} y={csy} down={curDown} />}
      {cap && <Caption text={cap.text} sub={cap.sub} opacity={cap.opacity} />}
      {brandIntro > 0.01 && <><div className="brand-scrim r-scope" data-theme={theme} style={{ opacity: brandIntro }} /><BrandLayer opacity={brandIntro} mode="intro" /></>}
      {brandOutro > 0.01 && <><div className="brand-scrim r-scope" data-theme={theme} style={{ opacity: brandOutro }} /><BrandLayer opacity={brandOutro} mode="outro" /></>}
    </div>
  );
}

function App() {
  return (
    <Stage width={CANVAS.w} height={CANVAS.h} duration={DUR} fps={30} background="#100e0c" persistKey="reader-promo">
      <Promo />
    </Stage>
  );
}

ReactDOM.createRoot(document.getElementById("root")).render(<App />);
