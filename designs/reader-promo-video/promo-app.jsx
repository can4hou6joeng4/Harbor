// promo-app.jsx — timeline controller: derive state + camera + cursor from time, render, mount.

const { useTime } = window;

/* ── helpers ── */
const seg = (t, a, b) => clamp((t - a) / (b - a), 0, 1);
const ease = Easing.easeInOutCubic;
const eo = Easing.easeOutCubic;
function kf(t, pts, e = ease) {
  return interpolate(pts.map((p) => p[0]), pts.map((p) => p[1]), e)(t);
}
const fade = (t, a, b, fi = 0.45, fo = 0.5) => Math.min(seg(t, a, a + fi), 1 - seg(t, b - fo, b));

/* ── camera keyframes: scale + center(canvas coords) ── */
const CAM_S = [[0,1.10],[4.0,1.00],[9.5,1.06],[9.8,1.50],[10.3,1.50],[10.9,1.22],[14.5,1.27],[15.2,1.06],
  [16.0,1.06],[16.7,1.18],[18.4,1.18],[18.9,1.10],[19.4,1.50],[21.4,1.50],[21.9,1.12],[24.4,1.12],
  [24.9,1.32],[25.6,1.32],[28.2,1.50],[29.0,1.50],[30.0,1.15],[31.4,1.15],[32.0,1.28],[34.7,1.28],
  [35.0,1.18],[38.0,1.18],[38.4,1.18],[40.6,1.20],[44.0,1.20],[47.6,1.20],[48.3,1.00],[55,1.00]];
const CAM_X = [[0,960],[4.0,960],[9.5,980],[9.8,470],[10.3,470],[10.9,960],[14.5,960],[15.2,900],
  [16.0,900],[16.7,960],[18.4,960],[18.9,760],[19.4,498],[21.4,498],[21.9,960],[24.4,960],
  [24.9,1230],[25.6,1230],[28.2,1232],[29.0,1232],[30.0,1430],[31.4,1430],[32.0,1230],[34.7,1230],
  [35.0,1430],[38.0,1450],[38.4,1500],[40.6,1500],[44.0,1500],[47.6,1500],[48.3,960],[55,960]];
const CAM_Y = [[0,540],[4.0,540],[9.5,540],[9.8,320],[10.3,320],[10.9,500],[14.5,510],[15.2,560],
  [16.0,560],[16.7,520],[18.4,520],[18.9,540],[19.4,540],[21.4,605],[21.9,470],[24.4,470],
  [24.9,540],[25.6,540],[28.2,470],[29.0,470],[30.0,380],[31.4,380],[32.0,545],[34.7,560],
  [35.0,500],[38.0,505],[38.4,540],[40.6,560],[44.0,520],[47.6,520],[48.3,540],[55,540]];

/* ── cursor: show windows + path (canvas coords) + click times ── */
const CUR_SHOW = [[9.8,16.95],[28.0,31.0],[37.9,44.9]];
const CUR_X = [[9.8,980],[10.25,294],[10.9,760],[12.6,760],[12.9,1208],[13.6,1208],[14.4,1180],[15.0,1180],[16.2,292],[16.5,292],
  [28.0,1120],[28.6,1300],[29.0,1176],[29.6,1480],[30.0,1710],[30.6,1665],[31.0,1665],
  [37.9,1500],[38.35,1626],[40.5,1714],[43.9,1802],[44.55,1660],[44.9,1660]];
const CUR_Y = [[9.8,600],[10.25,84],[10.9,452],[12.6,452],[12.9,452],[13.6,452],[14.4,742],[15.0,742],[16.2,306],[16.5,306],
  [28.0,470],[28.6,470],[29.0,452],[29.6,200],[30.0,84],[30.6,150],[31.0,150],
  [37.9,320],[38.35,135],[40.5,135],[43.9,135],[44.55,250],[44.9,250]];
const CLICKS = [10.3, 12.95, 14.6, 16.5, 29.0, 30.0, 30.7, 38.4, 40.6, 44.0, 44.6];
const curShown = (t) => CUR_SHOW.some(([a, b]) => t >= a && t <= b);

const SEL = { x: 1232, y: 480 };

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
  const brandIntro = 1 - seg(t, 2.7, 3.8);
  const brandOutro = seg(t, T.brandIn, T.brandIn + 0.9);

  /* ── capture ── */
  const modalPop = (t < T.capture[0] || t > T.cModalOut[1] + 0.05) ? 0
    : (t < T.cModalIn[1] ? seg(t, T.cModalIn[0], T.cModalIn[1]) : 1 - seg(t, T.cModalOut[0], T.cModalOut[1]));
  const fullURL = "wired.com/story/own-your-data";
  const typedN = Math.round(seg(t, T.cTypeStart, T.cTypeEnd) * fullURL.length);
  const typed = t >= T.cTypeStart ? fullURL.slice(0, typedN) : "";
  const showCaret = t >= T.cTypeStart && t < T.cFetch && Math.floor(t * 2) % 2 === 0;
  const fetched = t >= T.cFetch;
  const fetchReveal = seg(t, T.cFetchIn[0], T.cFetchIn[1]);
  const toastPop = (t < T.cToast[0] || t > T.cToast[1] + 0.4) ? 0 : Math.min(seg(t, T.cToast[0], T.cToast[0] + 0.3), 1 - seg(t, T.cToast[1], T.cToast[1] + 0.4));
  const newCardP = seg(t, T.cNewCard, T.cNewCard + 0.7);
  const newCard = t >= T.cNewCard ? { op: newCardP, ty: (1 - newCardP) * -10, mh: 30 + newCardP * 170 } : null;
  const addPulse = t >= 10.15 && t <= 10.55;

  /* ── subscriptions manager ── */
  const subsPop = (t < T.subsIn[0] || t > T.subsOut[1] + 0.05) ? 0
    : (t < T.subsIn[1] ? seg(t, T.subsIn[0], T.subsIn[1]) : 1 - seg(t, T.subsOut[0], T.subsOut[1]));

  /* ── command palette ── */
  const palPop = (t < T.palIn[0] || t > T.palOut[1] + 0.05) ? 0
    : (t < T.palIn[1] ? seg(t, T.palIn[0], T.palIn[1]) : 1 - seg(t, T.palOut[0], T.palOut[1]));
  const palN = Math.round(seg(t, T.palType[0], T.palType[1]) * PALETTE.query.length);
  const palTyped = t >= T.palType[0] ? PALETTE.query.slice(0, palN) : "";
  const palCaret = t >= T.palType[0] && t < T.palType[1] + 0.3 && Math.floor(t * 2) % 2 === 0;
  const palActive = t > T.palType[1] ? 3 : 0;

  /* ── reading ── */
  let scrollY = 0;
  if (t >= T.rScroll[0]) scrollY = kf(t, [[T.rScroll[0], 0], [T.rScroll[1], 312], [T.rScroll2[0], 312], [T.rScroll2[1], 470]], eo);
  const highlightOn = t >= T.rHl;
  const bilingual = t >= T.rBiToggle;
  const biReveal = seg(t, T.rBiIn[0], T.rBiIn[1]);
  const serif = t >= T.typoSerif;
  const typoOpen = t >= T.typoIn[0] && t < T.typoOut[1];
  const aiOpen = t >= T.aPanelIn[0];
  const readProgress = clamp(0.30 + scrollY / 760, 0.30, 0.96);
  const readingProgress = aiOpen ? 0.74 : (t >= T.read[0] ? readProgress : 0.42);
  const selPop = (t < T.rSelIn[0] || t > T.rHl + 0.15) ? 0 : Math.min(seg(t, T.rSelIn[0], T.rSelIn[1]), 1 - seg(t, T.rHl, T.rHl + 0.15));

  /* ── AI ── */
  const aiTab = t >= T.aRemixTab ? "remix" : t >= T.aChatTab ? "chat" : t >= T.aTransTab ? "translate" : "summary";
  const aiTx = (1 - seg(t, T.aPanelIn[0], T.aPanelIn[1])) * PANE.ai;
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
  const remix = { pick: t >= T.aRemixPick ? "rx-note" : null, out: seg(t, T.aRemixOut[0], T.aRemixOut[1]) };

  /* ── cursor + clicks ── */
  const cShown = curShown(t);
  const curX = kf(t, CUR_X, eo), curY = kf(t, CUR_Y, eo);
  const [csx, csy] = applyCam(s, cx, cy, curX, curY);
  const activeClick = CLICKS.find((c) => t >= c && t < c + 0.4);
  const curDown = activeClick != null && t < activeClick + 0.13;
  let ring = null;
  if (activeClick != null) { const [rx, ry] = applyCam(s, cx, cy, kf(activeClick, CUR_X, eo), kf(activeClick, CUR_Y, eo)); ring = { x: rx, y: ry, p: seg(t, activeClick, activeClick + 0.4) }; }

  const [selSx, selSy] = applyCam(s, cx, cy, SEL.x, SEL.y);

  /* active caption */
  let cap = null;
  for (const c of CAPTIONS) { const o = fade(t, c.start, c.end); if (o > 0.01) { cap = { ...c, opacity: o }; break; } }

  const label = "t=" + t.toFixed(1) + "s";

  return (
    <div className="r-scope stage-root" data-theme={theme} data-screen-label={label}>
      <div className="cam" style={{ transform: camTransform }}>
        <div className="desktop" />
        <div className="pwindow" style={{ left: WIN.x, top: WIN.y, width: WIN.w, height: WIN.h }}>
          <Sidebar theme={theme} addPulse={addPulse} />
          <ListPane selId="a1" newCard={newCard} />
          <ReaderPane scrollY={scrollY} progress={readingProgress} highlightOn={highlightOn}
                      bilingual={bilingual} biReveal={biReveal} serif={serif} typo={typoOpen}
                      bilingualBtn={bilingual} typoBtn={typoOpen} aiBtn={aiOpen} />
          {aiOpen && <AIPanel tx={aiTx} tab={aiTab} reveal={reveal} chat={chat} remix={remix} />}
          {modalPop > 0 && <AddModal pop={modalPop} typed={typed} showCaret={showCaret} fetched={fetched} fetchReveal={fetchReveal} />}
          {subsPop > 0 && <SubsModal pop={subsPop} />}
          {palPop > 0 && <CommandPalette pop={palPop} typed={palTyped} showCaret={palCaret} activeIdx={palActive} />}
          {toastPop > 0 && <Toast text="已保存到本地" pop={toastPop} />}
        </div>
      </div>

      {/* screen-space overlays */}
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
    <Stage width={CANVAS.w} height={CANVAS.h} duration={DUR} fps={30} background="#100e0c" persistKey="reader-promo-v2">
      <Promo />
    </Stage>
  );
}

ReactDOM.createRoot(document.getElementById("root")).render(<App />);
