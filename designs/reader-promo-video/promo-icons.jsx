// promo-icons.jsx — SF-style line icons used across the promo (exported to window)

const ICON_PATHS = {
  inbox: <><path d="M3 13.5h4l1.4 2.8a1 1 0 0 0 .9.55h5.4a1 1 0 0 0 .9-.55L17 13.5h4"/><path d="M3.2 13.5l2.4-7.2A2 2 0 0 1 7.5 5h9a2 2 0 0 1 1.9 1.3l2.4 7.2V18a2 2 0 0 1-2 2H5.2a2 2 0 0 1-2-2z"/></>,
  stack: <><path d="M12 3.2l8.5 4.6-8.5 4.6L3.5 7.8z"/><path d="M4 12l8 4.4 8-4.4M4 16.2l8 4.4 8-4.4"/></>,
  dot: <circle cx="12" cy="12" r="4" fill="currentColor" stroke="none"/>,
  star: <path d="M12 3.6l2.55 5.3 5.85.8-4.25 4.05 1.05 5.8L12 16.9l-5.2 2.65 1.05-5.8L3.6 9.7l5.85-.8z"/>,
  "star-fill": <path d="M12 3.6l2.55 5.3 5.85.8-4.25 4.05 1.05 5.8L12 16.9l-5.2 2.65 1.05-5.8L3.6 9.7l5.85-.8z" fill="currentColor" stroke="none"/>,
  clock: <><circle cx="12" cy="12" r="8.4"/><path d="M12 7.5V12l3.2 2"/></>,
  archive: <><rect x="3.5" y="4.5" width="17" height="4" rx="1.3"/><path d="M5 8.5V18a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V8.5"/><path d="M10 12h4"/></>,
  rss: <><circle cx="5.9" cy="18.1" r="1.7" fill="currentColor" stroke="none"/><path d="M5 11.6a8 8 0 0 1 8 8"/><path d="M5 5.6a14 14 0 0 1 14 14"/></>,
  x: <path d="M18.24 2.5h3.3l-7.2 8.23L23 21.5h-6.63l-5.2-6.79-5.93 6.79H1.93l7.7-8.8L1.5 2.5h6.8l4.69 6.2zM16.06 19.5h1.83L7 4.4H5.04z" fill="currentColor" stroke="none"/>,
  weibo: <path d="M19.5 12.2c0 3.4-4 6.3-8.6 6.3a11 11 0 0 1-3-.42L4 19.4l1.4-3.5a5.7 5.7 0 0 1-2-4c0-3.4 4-6.3 8.6-6.3s7.5 2.9 7.5 6.6z"/>,
  youtube: <><rect x="2.5" y="6" width="19" height="12" rx="3.4"/><path d="M10.4 9.2l5.2 2.8-5.2 2.8z" fill="currentColor" stroke="none"/></>,
  folder: <path d="M3.5 7.6a2 2 0 0 1 2-2h3.3a2 2 0 0 1 1.4.6l.9.9a2 2 0 0 0 1.4.6h5.5a2 2 0 0 1 2 2V17a2 2 0 0 1-2 2H5.5a2 2 0 0 1-2-2z"/>,
  tag: <><path d="M12.7 3.5H5a1.5 1.5 0 0 0-1.5 1.5v7.5a1.5 1.5 0 0 0 .44 1.06l7.8 7.8a1.5 1.5 0 0 0 2.12 0l6.5-6.5a1.5 1.5 0 0 0 0-2.12l-7.8-7.8A1.5 1.5 0 0 0 12.7 3.5z"/><circle cx="8" cy="8" r="1.3" fill="currentColor" stroke="none"/></>,
  sparkles: <><path d="M12 3.2l1.7 4.5 4.5 1.7-4.5 1.7L12 15.6l-1.7-4.5L5.8 9.4l4.5-1.7z" fill="currentColor" stroke="none"/><path d="M18.4 14.2l.65 1.75 1.75.65-1.75.65-.65 1.75-.65-1.75-1.75-.65 1.75-.65z" fill="currentColor" stroke="none"/></>,
  search: <><circle cx="10.5" cy="10.5" r="6.4"/><path d="M15.4 15.4L20 20"/></>,
  plus: <path d="M12 5v14M5 12h14"/>,
  minus: <path d="M5 12h14"/>,
  gear: <><circle cx="12" cy="12" r="3"/><path d="M19.1 14a1.6 1.6 0 0 0 .32 1.77l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.6 1.6 0 0 0-2.72 1.13V20a2 2 0 0 1-4 0v-.09a1.6 1.6 0 0 0-2.72-1.13l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06A1.6 1.6 0 0 0 4.5 14H4.4a2 2 0 0 1 0-4h.09a1.6 1.6 0 0 0 1.13-2.72l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06A1.6 1.6 0 0 0 10 4.5V4.4a2 2 0 0 1 4 0v.09a1.6 1.6 0 0 0 2.72 1.13l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06A1.6 1.6 0 0 0 19.5 10h.1a2 2 0 0 1 0 4z"/></>,
  "panel-right": <><rect x="3" y="4.5" width="18" height="15" rx="2.6"/><path d="M14.8 4.7v14.6"/></>,
  sun: <><circle cx="12" cy="12" r="4"/><path d="M12 2.6v2M12 19.4v2M2.6 12h2M19.4 12h2M5.1 5.1l1.4 1.4M17.5 17.5l1.4 1.4M18.9 5.1l-1.4 1.4M6.5 17.5l-1.4 1.4"/></>,
  moon: <path d="M20 13.6A8 8 0 1 1 10.4 4a6.5 6.5 0 0 0 9.6 9.6z"/>,
  send: <path d="M12 19V5.5M6.5 11l5.5-5.5L17.5 11"/>,
  link: <><path d="M9.5 14.5l5-5"/><path d="M8.2 12.2l-2 2a3.4 3.4 0 0 0 4.8 4.8l2-2"/><path d="M15.8 11.8l2-2a3.4 3.4 0 0 0-4.8-4.8l-2 2"/></>,
  paperclip: <path d="M20 11.6l-8.3 8.3a4.5 4.5 0 0 1-6.4-6.4l8.6-8.6a3 3 0 0 1 4.3 4.3l-8.5 8.5a1.5 1.5 0 0 1-2.1-2.1l7.8-7.8"/>,
  markdown: <><rect x="2.5" y="6" width="19" height="12" rx="2.6"/><path d="M6 15V9l3 3 3-3v6"/><path d="M17 9v6M14.8 12.8L17 15l2.2-2.2"/></>,
  doc: <><path d="M6 3.5h7l5 5V20a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1V4.5a1 1 0 0 1 1-1z"/><path d="M13 3.5V9h5"/><path d="M8.5 13.5h7M8.5 16.5h5"/></>,
  image: <><rect x="3.5" y="4.5" width="17" height="15" rx="2.6"/><circle cx="9" cy="10" r="1.6"/><path d="M4.5 17.5l4.5-4 3 2.5 4-3.5 4 4.5"/></>,
  video: <><rect x="3" y="5.5" width="13" height="13" rx="2.6"/><path d="M16 10l5-3v10l-5-3z" fill="currentColor" stroke="none"/></>,
  play: <path d="M7 5l12 7-12 7z" fill="currentColor" stroke="none"/>,
  close: <path d="M6 6l12 12M18 6L6 18"/>,
  chev: <path d="M9 5.5l6.5 6.5L9 18.5"/>,
  highlighter: <><path d="M9.5 13.8l-1 4.2 4.2-1L20.4 9a1.9 1.9 0 0 0-2.7-2.7z"/><path d="M14.5 6.8l3.4 3.4"/><path d="M7 21h6"/></>,
  pencil: <><path d="M4 20l1-4L16.4 4.6a2 2 0 0 1 2.8 2.8L7.8 19z"/><path d="M14 7l3 3"/></>,
  chat: <><path d="M20 11.6a7.6 6.6 0 0 1-10.8 6L4 19.2l1.7-4.2A6.5 6.5 0 0 1 4.4 11.6C4.4 8 8 5 12.2 5S20 8 20 11.6z"/><circle cx="9" cy="11.6" r=".9" fill="currentColor" stroke="none"/><circle cx="12.2" cy="11.6" r=".9" fill="currentColor" stroke="none"/><circle cx="15.4" cy="11.6" r=".9" fill="currentColor" stroke="none"/></>,
  translate: <><path d="M3 5.5h8.5"/><path d="M7 3.5v2c0 4.2-1.8 7.2-4 8.8"/><path d="M4.6 9.2c1.2 2.1 3.1 3.7 5.2 4.6"/><path d="M12.5 20.5l4-9 4 9M14 17.5h5"/></>,
  calendar: <><rect x="3.5" y="5" width="17" height="15" rx="2.4"/><path d="M3.5 9.5h17M8 3.5v3M16 3.5v3"/></>,
  check: <path d="M5 12.6l4.4 4.4L19 7.2"/>,
  "check-circle": <><circle cx="12" cy="12" r="8.5"/><path d="M8.2 12.3l2.7 2.7L16 9.5"/></>,
  ellipsis: <><circle cx="5.5" cy="12" r="1.6" fill="currentColor" stroke="none"/><circle cx="12" cy="12" r="1.6" fill="currentColor" stroke="none"/><circle cx="18.5" cy="12" r="1.6" fill="currentColor" stroke="none"/></>,
  share: <><path d="M12 3.6l3.4 3.4M12 3.6L8.6 7M12 3.6V15"/><path d="M6.5 11H5.5A1.6 1.6 0 0 0 4 12.6V19A1.6 1.6 0 0 0 5.5 20.5h13A1.6 1.6 0 0 0 20 19v-6.4A1.6 1.6 0 0 0 18.5 11h-1"/></>,
  globe: <><circle cx="12" cy="12" r="8.4"/><path d="M3.6 12h16.8M12 3.6c2.4 2.3 2.4 14.5 0 16.8M12 3.6c-2.4 2.3-2.4 14.5 0 16.8"/></>,
  list: <path d="M8.5 6.5h11M8.5 12h11M8.5 17.5h11M4.3 6.5h.02M4.3 12h.02M4.3 17.5h.02"/>,
  sort: <><path d="M7 4.5v15M7 19.5l-3-3M7 19.5l3-3"/><path d="M13 7h7M13 12h5M13 17h3"/></>,
  wand: <><path d="M5 19l9.5-9.5M16 6l2.5 2.5"/><path d="M14 4l.6 1.6L16.2 6.2 14.6 6.8 14 8.4l-.6-1.6L11.8 6.2 13.4 5.6z" fill="currentColor" stroke="none"/><path d="M19.2 11.4l.45 1.2 1.2.45-1.2.45-.45 1.2-.45-1.2-1.2-.45 1.2-.45z" fill="currentColor" stroke="none"/></>,
  eye: <><path d="M2.6 12S6 5.6 12 5.6 21.4 12 21.4 12 18 18.4 12 18.4 2.6 12 2.6 12z"/><circle cx="12" cy="12" r="3"/></>,
  copy: <><rect x="8.5" y="8.5" width="11" height="11" rx="2.4"/><path d="M5.8 15.5H5A1.5 1.5 0 0 1 3.5 14V5A1.5 1.5 0 0 1 5 3.5h9A1.5 1.5 0 0 1 15.5 5v.6"/></>,
  bookmark: <path d="M6 4.5h12a.5.5 0 0 1 .5.5v15l-6.5-4-6.5 4V5a.5.5 0 0 1 .5-.5z"/>,
  "book-open": <><path d="M12 6.5C10.5 5.3 8.4 4.8 5.5 5a1 1 0 0 0-1 1v11.2a1 1 0 0 0 1.1 1c2.6-.2 4.6.3 5.9 1.3M12 6.5c1.5-1.2 3.6-1.7 6.5-1.5a1 1 0 0 1 1 1V17.2a1 1 0 0 1-1.1 1c-2.6-.2-4.6.3-5.9 1.3M12 6.5v13"/></>,
};

function Icon({ name, size = 18, style, className }) {
  const body = ICON_PATHS[name] || ICON_PATHS.globe;
  return (
    <svg viewBox="0 0 24 24" width={size} height={size} fill="none" stroke="currentColor"
         strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" style={style} className={className}>
      {body}
    </svg>
  );
}

function kindIcon(kind) {
  return ({ web: "globe", rss: "rss", x: "x", weibo: "weibo", youtube: "youtube",
            pdf: "doc", markdown: "markdown", image: "image", video: "video" })[kind] || "globe";
}

Object.assign(window, { Icon, kindIcon, ICON_PATHS });
