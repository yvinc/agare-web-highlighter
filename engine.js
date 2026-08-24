/* Agare core — no deps. Attaches globalThis.Lumen */
(() => {
  const COLORS = [
    { f: "#fff59e", n: "#b89c18", k: "Lemon" },
    { f: "#fa9442", n: "#c45a12", k: "Tangerine" },
    { f: "#a3ad00", n: "#6d7400", k: "Olive" },
    { f: "#de4500", n: "#a83300", k: "Ember" },
    { f: "#96bfe6", n: "#4a7eab", k: "Sky" },
    { f: "#bf36e0", n: "#8a14a8", k: "Violet" },
  ];
  const PRE = 24, SUF = 24, MAX_E = 2400, MAX_N = 1600, MAX_H = 160;
  const SKIP = { SCRIPT: 1, STYLE: 1, NOSCRIPT: 1, TEXTAREA: 1, INPUT: 1, SELECT: 1, BUTTON: 1 };
  const TRACK = /^(utm_|fbclid$|gclid$|mc_|yclid$|igshid$|ref$|ref_|spm$|si$)/i;

  const nid = () => {
    const b = new Uint8Array(5);
    crypto.getRandomValues(b);
    return Array.from(b, (x) => x.toString(36).padStart(2, "0")).join("").slice(0, 7);
  };

  const djb2 = (s) => {
    let h = 5381;
    for (let i = 0; i < s.length; i++) h = ((h << 5) + h + s.charCodeAt(i)) >>> 0;
    return h.toString(36);
  };

  const storeKey = (u) => "lumen.p." + djb2(u);

  const pageKey = (href) => {
    let u;
    try { u = new URL(href); } catch { return href; }
    u.hash = "";
    if (u.search) {
      const sp = new URLSearchParams(u.search);
      for (const k of [...sp.keys()]) {
        if (TRACK.test(k) || k.toLowerCase().startsWith("utm_")) sp.delete(k);
      }
      u.search = sp.toString();
    }
    if (u.pathname.length > 1 && u.pathname.endsWith("/")) u.pathname = u.pathname.slice(0, -1);
    return u.origin + u.pathname + u.search;
  };

  const hostFrom = (u) => {
    try { return new URL(u).hostname; } catch { return u; }
  };

  const clampGate = (raw) => {
    const out = { p: {}, h: {} };
    if (!raw || typeof raw !== "object") return out;
    const copy = (src, dest) => {
      if (!src || typeof src !== "object") return;
      let n = 0;
      for (const [k, v] of Object.entries(src)) {
        if (n >= 400) break;
        if (typeof k !== "string" || !k || k.length > 2000) continue;
        if (v === 0 || v === 1) { dest[k] = v; n += 1; }
      }
    };
    copy(raw.p, out.p);
    copy(raw.h, out.h);
    return out;
  };

  const isHostOn = (host, gate, mode) => {
    if (Object.prototype.hasOwnProperty.call(gate.h, host)) return gate.h[host] === 1;
    return mode !== "ask";
  };

  const isPageOn = (page, gate, mode) => {
    if (Object.prototype.hasOwnProperty.call(gate.p, page)) return gate.p[page] === 1;
    return isHostOn(hostFrom(page), gate, mode);
  };

  const inChrome = (node) => {
    const el = node.nodeType === 1 ? node : node.parentElement;
    return !!(el && el.closest && el.closest("#lumen-root, .lumen-ui"));
  };

  const collect = (root) => {
    const nodes = [];
    let text = "";
    const w = document.createTreeWalker(root, NodeFilter.SHOW_TEXT, {
      acceptNode(n) {
        if (!n.nodeValue) return 2;
        const p = n.parentElement;
        if (!p || SKIP[p.tagName] || inChrome(n)) return 2;
        return 1;
      },
    });
    let n;
    while ((n = w.nextNode())) {
      nodes.push({ n, start: text.length });
      text += n.nodeValue;
    }
    return { text, nodes };
  };

  const rangeOff = (root, range) => {
    const probe = document.createRange();
    probe.selectNodeContents(root);
    try { probe.setEnd(range.startContainer, range.startOffset); } catch { return 0; }
    return probe.toString().length;
  };

  const quoteFromRange = (range, root) => {
    const e = range.toString().replace(/\s+/g, " ").trim().slice(0, MAX_E);
    const { text } = collect(root);
    const start = Math.max(0, rangeOff(root, range));
    const end = start + range.toString().length;
    return {
      e,
      p: text.slice(Math.max(0, start - PRE), start),
      s: text.slice(end, end + SUF),
    };
  };

  const offsetsToRange = (index, from, to) => {
    if (to <= from) return null;
    let sn = null, so = 0, en = null, eo = 0;
    for (const { n, start } of index.nodes) {
      const stop = start + (n.nodeValue ? n.nodeValue.length : 0);
      if (!sn && from >= start && from <= stop) { sn = n; so = from - start; }
      if (to >= start && to <= stop) { en = n; eo = to - start; break; }
    }
    if (!sn || !en) return null;
    const r = document.createRange();
    try { r.setStart(sn, so); r.setEnd(en, eo); } catch { return null; }
    return r;
  };

  const rangeFromQuote = (root, q) => {
    const index = collect(root);
    const { text } = index;
    if (!q.e) return null;
    let at = -1;
    if (q.p || q.s) {
      const f = text.indexOf(q.p + q.e + q.s);
      if (f >= 0) at = f + q.p.length;
    }
    if (at < 0) at = text.indexOf(q.e);
    if (at < 0) return null;
    return offsetsToRange(index, at, at + q.e.length);
  };

  const makeMark = (m) => {
    const el = document.createElement("span");
    const pen = COLORS[m.c] || COLORS[0];
    el.className = "lumen-hl";
    el.dataset.id = m.i;
    el.dataset.c = String(m.c);
    el.style.setProperty("--lumen-fill", pen.f);
    el.style.setProperty("--lumen-note", pen.n);
    if (m.n) el.dataset.noted = "1";
    return el;
  };

  const unwrapAll = (root) => {
    root.querySelectorAll("span.lumen-hl").forEach((el) => {
      const p = el.parentNode;
      if (!p) return;
      while (el.firstChild) p.insertBefore(el.firstChild, el);
      p.removeChild(el);
      p.normalize();
    });
  };

  const wrapRange = (range, m) => {
    try {
      if (range.startContainer === range.endContainer && range.startContainer.nodeType === 3) {
        if (range.startContainer.parentElement && range.startContainer.parentElement.closest("span.lumen-hl")) return [];
        const el = makeMark(m);
        range.surroundContents(el);
        return [el];
      }
    } catch (_) { /* multi-node */ }
    const nodes = [];
    const w = document.createTreeWalker(range.commonAncestorContainer, NodeFilter.SHOW_TEXT, {
      acceptNode(n) {
        if (!n.nodeValue || inChrome(n)) return 2;
        const p = n.parentElement;
        if (p && SKIP[p.tagName]) return 2;
        return range.intersectsNode(n) ? 1 : 2;
      },
    });
    let n;
    while ((n = w.nextNode())) nodes.push(n);
    const marks = [];
    for (let i = nodes.length - 1; i >= 0; i--) {
      const text = nodes[i];
      if (!text.parentNode) continue;
      if (text.parentElement && text.parentElement.closest("span.lumen-hl")) continue;
      let start = 0, end = text.length;
      if (text === range.startContainer) start = range.startOffset;
      if (text === range.endContainer) end = range.endOffset;
      if (start >= end) continue;
      if (end < text.length) text.splitText(end);
      const piece = start > 0 ? text.splitText(start) : text;
      const el = makeMark(m);
      piece.parentNode.insertBefore(el, piece);
      el.appendChild(piece);
      marks.push(el);
    }
    return marks;
  };

  const restore = (root, marks) => {
    unwrapAll(root);
    const ordered = marks.slice().sort((a, b) => a.e.length - b.e.length || a.t - b.t);
    for (const m of ordered) {
      const r = rangeFromQuote(root, m);
      if (r) wrapRange(r, m);
    }
  };

  const markIdFromRange = (range) => {
    const n = range.commonAncestorContainer;
    const el = n.nodeType === 1 ? n : n.parentElement;
    const hl = el && el.closest && el.closest("span.lumen-hl");
    return hl ? hl.dataset.id : "";
  };

  const selInside = () => {
    const sel = document.getSelection();
    if (!sel || sel.isCollapsed || !sel.rangeCount) return null;
    const r = sel.getRangeAt(0);
    const el = r.commonAncestorContainer.nodeType === 1
      ? r.commonAncestorContainer
      : r.commonAncestorContainer.parentElement;
    if (!el || inChrome(r.commonAncestorContainer)) return null;
    if (!r.toString().trim()) return null;
    return r;
  };

  const clampMark = (m) => {
    if (!m || typeof m !== "object" || typeof m.e !== "string" || !m.e) return null;
    const out = {
      i: typeof m.i === "string" ? m.i.slice(0, 12) : nid(),
      c: Number.isInteger(m.c) && m.c >= 0 && m.c <= 5 ? m.c : 0,
      e: m.e.slice(0, MAX_E),
      p: typeof m.p === "string" ? m.p.slice(0, PRE) : "",
      s: typeof m.s === "string" ? m.s.slice(0, SUF) : "",
      t: typeof m.t === "number" ? m.t : (Date.now() / 1000) | 0,
    };
    if (typeof m.n === "string" && m.n.trim()) out.n = m.n.trim().slice(0, MAX_N);
    return out;
  };

  globalThis.Lumen = {
    COLORS, PRE, SUF, MAX_E, MAX_N, MAX_H, nid, djb2, storeKey, pageKey,
    quoteFromRange, rangeFromQuote, wrapRange, unwrapAll, restore, selInside,
    clampMark, makeMark, hostFrom, clampGate, isHostOn, isPageOn, markIdFromRange,
  };
})();
