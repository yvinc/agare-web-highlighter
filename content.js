(() => {
  document.querySelectorAll("#lumen-root").forEach((n) => n.remove());
  window.__lumenBooted = true;
  const L = globalThis.Lumen;
  if (!L) return;
  const api = globalThis.browser ?? globalThis.chrome;
  const root = document.body || document.documentElement;

  const hostEl = document.createElement("div");
  hostEl.id = "lumen-root";
  hostEl.className = "lumen-ui";
  const shadow = hostEl.attachShadow({ mode: "open" });
  const link = document.createElement("link");
  link.rel = "stylesheet";
  link.href = api.runtime.getURL("ui.css");
  shadow.appendChild(link);

  const ui = document.createElement("div");
  ui.innerHTML = `
    <div class="toolbar" hidden></div>
    <div class="bubble" hidden><div class="bubble-bar"></div><p></p></div>
    <aside class="panel" part="panel">
      <header class="ph">
        <div>
          <p class="eyebrow">This page</p>
          <h2></h2>
          <p class="url"></p>
        </div>
        <button class="icon-btn close" type="button" aria-label="Close">✕</button>
      </header>
      <div class="paused" hidden></div>
      <nav class="tabs">
        <button class="tab on" data-tab="highlights" type="button">Highlights</button>
        <button class="tab" data-tab="notes" type="button">Notes</button>
        <button class="tab" data-tab="settings" type="button">Settings</button>
      </nav>
      <div class="list"></div>
      <div class="settings" hidden></div>
    </aside>
  `;
  shadow.appendChild(ui);
  (document.documentElement || document.body).appendChild(hostEl);

  const $ = (sel) => shadow.querySelector(sel);
  const toolbar = $(".toolbar");
  const bubble = $(".bubble");
  const panel = $(".panel");
  const listEl = $(".list");
  const settingsEl = $(".settings");
  const pausedEl = $(".paused");
  const titleEl = $(".ph h2");
  const urlEl = $(".url");

  let page = L.pageKey(location.href);
  let host = L.hostFrom(page);
  let marks = [];
  let opacity = 46;
  let pen = 0;
  let mode = "ask";
  let gate = { p: {}, h: {} };
  let tab = "highlights";
  let draft = null;
  let lastUrl = location.href;
  let tb = null;
  let popupNote = "";

  const storageGet = (keys) => {
    try {
      const r = api.storage.local.get(keys);
      if (r && typeof r.then === "function") return r.then((v) => v || {});
    } catch (_) { /* callback API */ }
    return new Promise((res) => api.storage.local.get(keys, (v) => res(v || {})));
  };
  const storageSet = (obj) => {
    try {
      const r = api.storage.local.set(obj);
      if (r && typeof r.then === "function") return r;
    } catch (_) { /* callback API */ }
    return new Promise((res) => api.storage.local.set(obj, res));
  };
  const storageRemove = (key) => {
    try {
      const r = api.storage.local.remove(key);
      if (r && typeof r.then === "function") return r;
    } catch (_) { /* callback API */ }
    return new Promise((res) => api.storage.local.remove(key, res));
  };

  const pageOn = () => L.isPageOn(page, gate, mode);
  const hostOn = () => L.isHostOn(host, gate, mode);

  const syncIcon = () => {
    try { api.runtime.sendMessage({ type: "lumen:icon", on: pageOn() }); } catch (_) {}
  };

  const applyOpacity = () => {
    document.documentElement.style.setProperty("--lumen-a", opacity + "%");
  };

  const persistPage = async () => {
    const key = L.storeKey(page);
    if (!marks.length) {
      await storageRemove(key);
      return;
    }
    await storageSet({ [key]: { u: page, h: marks.slice(0, L.MAX_H) } });
  };

  const persistSettings = () => storageSet({ "lumen.s": { a: opacity, c: pen, m: mode } });
  const persistGate = () => storageSet({ "lumen.g": gate });

  const paintMarks = () => {
    if (pageOn()) L.restore(root, marks);
    else L.unwrapAll(root);
    syncIcon();
  };

  const load = async () => {
    page = L.pageKey(location.href);
    host = L.hostFrom(page);
    const key = L.storeKey(page);
    const bag = await storageGet(["lumen.s", "lumen.g", key]);
    const s = bag["lumen.s"];
    if (s && typeof s.a === "number") opacity = s.a;
    if (s && Number.isInteger(s.c)) pen = s.c;
    if (!s) mode = "ask";
    else mode = s.m === "ask" ? "ask" : "all";
    gate = L.clampGate(bag["lumen.g"]);
    const blob = bag[key];
    marks = Array.isArray(blob && blob.h)
      ? blob.h.map(L.clampMark).filter(Boolean)
      : [];
    applyOpacity();
    paintMarks();
    render();
  };

  const hideToolbar = () => {
    toolbar.hidden = true;
    toolbar.classList.remove("is-open");
    toolbar.style.display = "none";
    toolbar.style.visibility = "hidden";
    tb = null;
    popupNote = "";
    document.querySelectorAll("#lumen-root").forEach((host) => {
      const sr = host.shadowRoot;
      if (!sr) return;
      sr.querySelectorAll(".toolbar").forEach((t) => {
        t.hidden = true;
        t.classList.remove("is-open");
        t.style.display = "none";
        t.style.visibility = "hidden";
      });
      if (host !== hostEl) host.remove();
    });
  };
  const hideBubble = () => { bubble.hidden = true; };

  const place = (el, x, y) => {
    el.style.left = x + "px";
    el.style.top = Math.max(8, y) + "px";
    el.classList.toggle("below", y < (tb && tb.noteOpen ? 200 : 56));
  };

  const editingMark = () => (tb && tb.id ? marks.find((m) => m.i === tb.id) : null);

  const noteSvg =
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 20h9"/><path d="M16.5 3.5a2.12 2.12 0 0 1 3 3L7 19l-4 1 1-4Z"/></svg>';
  const trashSvg =
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 6h18"/><path d="M19 6v14c0 1-1 2-2 2H7c-1 0-2-1-2-2V6"/><path d="M8 6V4c0-1 1-2 2-2h4c1 0 2 1 2 2v2"/><line x1="10" x2="10" y1="11" y2="17"/><line x1="14" x2="14" y1="11" y2="17"/></svg>';
  const xSvg =
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round"><path d="M6 6l12 12M18 6L6 18"/></svg>';
  const closeBtn =
    `<button class="tb-close" data-act="tb-close" type="button" aria-label="Close">${xSvg}</button>`;

  const drawToolbar = (rect) => {
    locked = false;
    shownAt = Date.now();
    toolbar.hidden = false;
    toolbar.classList.add("is-open");
    toolbar.style.display = "flex";
    toolbar.style.visibility = "visible";
    if (tb && tb.kind === "enable") {
      toolbar.innerHTML = `${closeBtn}<div class="enable">
        <p>Agare is off on this page.</p>
        <div class="enable-row">
          <button class="btn" data-act="on-page" type="button">This page</button>
          <button class="btn ghost line" data-act="on-host" type="button">${esc(host)}</button>
        </div>
      </div>`;
      place(toolbar, rect.left + rect.width / 2, rect.top);
      return;
    }
    const cur = editingMark();
    const current = cur ? cur.c : pen;
    const colors = L.COLORS.map(
      (c, i) =>
        `<button class="dot${i === current ? " on" : ""}" type="button" data-c="${i}" aria-label="${c.k}" style="background:${c.f}"></button>`,
    ).join("");
    const noteLabel = cur && cur.n ? "Edit note" : "Add note";
    let html = `${closeBtn}<div class="tb-row">${colors}<span class="sep"></span>
      <button class="icon-btn note-btn${tb && tb.noteOpen ? " on" : ""}" type="button" aria-label="${noteLabel}" title="${noteLabel}">${noteSvg}</button>
      ${cur ? `<button class="icon-btn" data-act="del-hl" type="button" aria-label="Remove highlight" title="Remove highlight">${trashSvg}</button>` : ""}</div>`;
    if (tb && tb.noteOpen) {
      html += `<textarea class="tb-note" maxlength="1600" placeholder="Write a note for this sentence">${esc(popupNote)}</textarea>
        <div class="tb-actions">
          ${cur && cur.n ? '<button class="btn ghost danger-text" data-act="note-clear" type="button">Remove note</button>' : ""}
          <button class="btn ghost" data-act="note-cancel" type="button">Cancel</button>
          <button class="btn" data-act="note-save" type="button">Save note</button>
        </div>`;
    }
    toolbar.innerHTML = html;
    place(toolbar, rect.left + rect.width / 2, rect.top);
    if (tb && tb.noteOpen) {
      const ta = toolbar.querySelector("textarea");
      if (ta) {
        ta.focus();
        ta.selectionStart = ta.value.length;
      }
    }
  };

  const uiEvent = (e) => {
    const path = e.composedPath ? e.composedPath() : [];
    if (path.includes(toolbar) || path.includes(panel)) return true;
    const t = e.target;
    return !!(t && (toolbar.contains(t) || panel.contains(t)));
  };

  const findHighlight = (e) => {
    const path = e.composedPath ? e.composedPath() : [];
    for (let i = 0; i < path.length; i++) {
      const n = path[i];
      if (n && n.classList && n.classList.contains("lumen-hl")) return n;
    }
    let t = e.target;
    if (t && t.nodeType === 3) t = t.parentElement;
    const via = t && t.closest ? t.closest("span.lumen-hl") : null;
    if (via) return via;
    const pts = (document.elementsFromPoint && document.elementsFromPoint(e.clientX, e.clientY)) || [];
    for (let i = 0; i < pts.length; i++) {
      const n = pts[i];
      if (!n || n === hostEl || (n.id && n.id === "lumen-root")) continue;
      const hl = n.closest && n.closest("span.lumen-hl");
      if (hl) return hl;
    }
    return null;
  };

  const openHighlightBar = (hl) => {
    if (!hl) return false;
    if (!pageOn()) return false;
    const id = hl.getAttribute("data-id") || (hl.dataset && hl.dataset.id);
    const m = marks.find((x) => x.i === id);
    if (!m) return false;
    locked = false;
    hideBubble();
    showEdit(m, hl, !!(tb && tb.id === m.i && tb.noteOpen));
    return true;
  };

  let gesture = null;
  let locked = false;
  let shownAt = 0;

  const dismissPopup = () => {
    locked = true;
    hideToolbar();
    hideBubble();
    const sel = document.getSelection();
    if (sel && !sel.isCollapsed) sel.removeAllRanges();
  };

  const showSelectToolbar = () => {
    if (locked) return;
    const range = L.selInside();
    if (!range) {
      hideToolbar();
      return;
    }
    const r = range.getBoundingClientRect();
    if (!pageOn()) {
      tb = { kind: "enable" };
      drawToolbar(r);
      return;
    }
    tb = { kind: "select" };
    drawToolbar(r);
  };

  const showEdit = (m, el, noteOpen, keepDraft) => {
    const node = el || document.querySelector(`span.lumen-hl[data-id="${CSS.escape(m.i)}"]`);
    const r = node ? node.getBoundingClientRect() : { left: 24, width: 0, top: 48 };
    tb = { kind: "edit", id: m.i, noteOpen: !!noteOpen };
    if (!keepDraft) popupNote = m.n || "";
    hideBubble();
    drawToolbar(r);
  };

  const turnOn = (scope) => {
    if (scope === "page") gate = { p: { ...gate.p, [page]: 1 }, h: { ...gate.h } };
    else {
      const p = { ...gate.p };
      delete p[page];
      gate = { p, h: { ...gate.h, [host]: 1 } };
    }
    persistGate();
    hideToolbar();
    paintMarks();
    render();
  };

  const paint = (color, withNote) => {
    if (!pageOn()) return;
    const range = L.selInside();
    if (!range) return;
    const q = L.quoteFromRange(range, root);
    if (!q.e) return;
    const existing = marks.find((m) => m.e === q.e && m.p === q.p);
    const hostId = L.markIdFromRange(range);
    const rect = range.getBoundingClientRect();
    document.getSelection()?.removeAllRanges();
    if (existing) {
      existing.c = color;
      pen = color;
      paintMarks();
      persistPage();
      persistSettings();
      showEdit(existing, null, withNote);
      render();
      return;
    }
    const m = { i: L.nid(), c: color, e: q.e, p: q.p, s: q.s, t: (Date.now() / 1000) | 0 };
    const wrapped = L.wrapRange(range, m);
    if (!wrapped.length) {
      const host = hostId ? marks.find((x) => x.i === hostId) : null;
      if (host) {
        host.c = color;
        pen = color;
        paintMarks();
        persistPage();
        persistSettings();
        showEdit(host, null, withNote);
        render();
      }
      return;
    }
    marks.push(m);
    pen = color;
    persistPage();
    persistSettings();
    const el = document.querySelector(`span.lumen-hl[data-id="${CSS.escape(m.i)}"]`);
    showEdit(m, el, withNote);
    if (!el) drawToolbar(rect);
    render();
  };

  const recast = (color) => {
    if (tb && tb.id) {
      const m = marks.find((x) => x.i === tb.id);
      if (!m) return;
      m.c = color;
      pen = color;
      paintMarks();
      persistPage();
      persistSettings();
      const el = document.querySelector(`span.lumen-hl[data-id="${CSS.escape(m.i)}"]`);
      showEdit(m, el, tb.noteOpen, true);
      render();
      return;
    }
    paint(color, false);
  };

  const openNoteInPopup = () => {
    if (tb && tb.id) {
      const m = marks.find((x) => x.i === tb.id);
      if (!m) return;
      popupNote = m.n || "";
      const el = document.querySelector(`span.lumen-hl[data-id="${CSS.escape(m.i)}"]`);
      showEdit(m, el, true);
      return;
    }
    paint(pen, true);
  };

  const savePopupNote = () => {
    if (!tb || !tb.id) return;
    const m = marks.find((x) => x.i === tb.id);
    if (!m) return;
    const n = popupNote.trim().slice(0, L.MAX_N);
    if (n) m.n = n;
    else delete m.n;
    paintMarks();
    persistPage();
    const el = document.querySelector(`span.lumen-hl[data-id="${CSS.escape(m.i)}"]`);
    showEdit(m, el, false);
    render();
  };

  const clearPopupNote = () => {
    if (!tb || !tb.id) return;
    const m = marks.find((x) => x.i === tb.id);
    if (!m) return;
    delete m.n;
    popupNote = "";
    paintMarks();
    persistPage();
    const el = document.querySelector(`span.lumen-hl[data-id="${CSS.escape(m.i)}"]`);
    showEdit(m, el, false);
    render();
  };

  const deleteHighlight = () => {
    if (!tb || !tb.id) return;
    const id = tb.id;
    marks = marks.filter((x) => x.i !== id);
    if (draft && draft.i === id) draft = null;
    hideToolbar();
    paintMarks();
    persistPage();
    render();
  };

  const openNote = (m) => {
    draft = m;
    tab = "notes";
    panel.classList.add("open");
    render();
    const ta = shadow.querySelector("textarea");
    if (ta) ta.focus();
  };

  toolbar.addEventListener("pointerdown", (e) => {
    if (e.target.closest && e.target.closest("[data-act='tb-close']")) {
      e.preventDefault();
      e.stopPropagation();
      dismissPopup();
      gesture = { ui: true };
      return;
    }
    if (e.target.closest && e.target.closest("textarea")) return;
    e.preventDefault();
  });
  toolbar.addEventListener("mousedown", (e) => {
    if (e.target.closest && e.target.closest("textarea")) return;
    e.preventDefault();
  });
  toolbar.addEventListener("input", (e) => {
    if (e.target.tagName === "TEXTAREA") popupNote = e.target.value;
  });
  toolbar.addEventListener("click", (e) => {
    const act = e.target.closest("[data-act]");
    if (act && act.dataset.act === "tb-close") { dismissPopup(); return; }
    if (act && act.dataset.act === "on-page") { turnOn("page"); return; }
    if (act && act.dataset.act === "on-host") { turnOn("host"); return; }
    if (act && act.dataset.act === "note-cancel") {
      if (tb) tb.noteOpen = false;
      const m = editingMark();
      const el = m && document.querySelector(`span.lumen-hl[data-id="${CSS.escape(m.i)}"]`);
      if (m) showEdit(m, el, false);
      return;
    }
    if (act && act.dataset.act === "note-save") { savePopupNote(); return; }
    if (act && act.dataset.act === "note-clear") { clearPopupNote(); return; }
    if (act && act.dataset.act === "del-hl") { deleteHighlight(); return; }
    const dot = e.target.closest("[data-c]");
    if (dot) recast(Number(dot.dataset.c));
    if (e.target.closest(".note-btn")) openNoteInPopup();
  });

  shadow.addEventListener("pointerdown", (e) => {
    if (e.target.closest && e.target.closest("[data-act='tb-close']")) {
      e.preventDefault();
      e.stopPropagation();
      dismissPopup();
      gesture = { ui: true };
    }
  }, true);

  const onPointerDown = (e) => {
    if (e.button != null && e.button !== 0) return;
    if (uiEvent(e)) {
      gesture = { ui: true };
      return;
    }
    const hl = findHighlight(e);
    gesture = { x: e.clientX, y: e.clientY, hl };
    if (hl) {
      openHighlightBar(hl);
      return;
    }
    hideToolbar();
  };

  const onPointerUp = (e) => {
    const g = gesture;
    gesture = null;
    if (!g || g.ui || uiEvent(e)) return;
    const dragged = Math.hypot(e.clientX - g.x, e.clientY - g.y) > 12;
    const hl = g.hl || findHighlight(e);
    requestAnimationFrame(() => {
      if (hl && !dragged) {
        openHighlightBar(hl);
        return;
      }
      if (dragged) {
        const range = L.selInside();
        const selected = range ? range.toString().replace(/\s+/g, " ").trim() : "";
        const inner = hl ? (hl.textContent || "").replace(/\s+/g, " ").trim() : "";
        if (range && (!hl || selected.length > inner.length + 2)) {
          locked = false;
          showSelectToolbar();
          return;
        }
        if (hl) {
          openHighlightBar(hl);
          return;
        }
      }
      dismissPopup();
    });
  };

  const onPageClick = (e) => {
    if (uiEvent(e)) return;
    const hl = findHighlight(e);
    if (hl) {
      if (e.detail >= 2) return;
      openHighlightBar(hl);
      e.stopPropagation();
      return;
    }
    if (toolbar.hidden) return;
    if (Date.now() - shownAt < 300) return;
    dismissPopup();
  };

  document.addEventListener("pointerdown", onPointerDown, true);
  document.addEventListener("mousedown", onPointerDown, true);
  document.addEventListener("pointerup", onPointerUp, true);
  document.addEventListener("mouseup", onPointerUp, true);
  document.addEventListener("click", onPageClick, true);
  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape") dismissPopup();
  }, true);

  root.addEventListener("mouseover", (e) => {
    if (!pageOn() || (tb && tb.kind === "edit")) { hideBubble(); return; }
    const hl = e.target.closest && e.target.closest("span.lumen-hl");
    if (!hl || hl.dataset.noted !== "1") { hideBubble(); return; }
    const m = marks.find((x) => x.i === hl.dataset.id);
    if (!m || !m.n) { hideBubble(); return; }
    const r = hl.getBoundingClientRect();
    const penN = (L.COLORS[m.c] || L.COLORS[0]).n;
    bubble.hidden = false;
    bubble.querySelector(".bubble-bar").style.background = penN;
    bubble.querySelector("p").textContent = m.n;
    place(bubble, r.left + r.width / 2, r.top);
  });
  root.addEventListener("mouseout", (e) => {
    if (!e.target.closest || !e.target.closest("span.lumen-hl")) hideBubble();
  });
  root.addEventListener("dblclick", (e) => {
    if (!pageOn()) return;
    const hl = e.target.closest && e.target.closest("span.lumen-hl");
    if (!hl) return;
    e.preventDefault();
    const m = marks.find((x) => x.i === hl.dataset.id);
    if (!m) return;
    const sel = document.getSelection();
    if (sel) sel.removeAllRanges();
    hideToolbar();
    hideBubble();
    tab = m.n ? "notes" : "highlights";
    panel.classList.add("open");
    render();
    const card = listEl.querySelector(`.card[data-id="${CSS.escape(m.i)}"]`);
    if (card) card.scrollIntoView({ block: "nearest" });
  });

  const ESC = { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" };
  const esc = (s) => String(s).replace(/[&<>"']/g, (c) => ESC[c]);

  const listOtherRules = () => {
    const rows = [];
    for (const [k, v] of Object.entries(gate.h || {})) {
      if (k === host) continue;
      rows.push({ kind: "h", k, on: v === 1 });
    }
    for (const [k, v] of Object.entries(gate.p || {})) {
      if (k === page) continue;
      rows.push({ kind: "p", k, on: v === 1 });
    }
    rows.sort((a, b) => a.k.localeCompare(b.k));
    return rows;
  };

  const render = () => {
    titleEl.textContent = document.title || "This page";
    urlEl.textContent = page.replace(/^https?:\/\//, "");
    shadow.querySelectorAll(".tab").forEach((t) => {
      t.classList.toggle("on", t.dataset.tab === tab);
    });
    const hlTab = shadow.querySelector('[data-tab="highlights"]');
    const nTab = shadow.querySelector('[data-tab="notes"]');
    const notes = marks.filter((m) => m.n);
    if (hlTab) hlTab.textContent = "Highlights " + marks.length;
    if (nTab) nTab.textContent = "Notes " + notes.length;

    if (!pageOn()) {
      pausedEl.hidden = false;
      pausedEl.innerHTML = `<p>Highlighting is off here. Select a sentence to turn Agare on for this page or for ${esc(host)}.</p>
        <div class="enable-row">
          <button class="btn" data-act="on-page" type="button">This page</button>
          <button class="btn ghost line" data-act="on-host" type="button">${esc(host)}</button>
        </div>`;
    } else {
      pausedEl.hidden = true;
      pausedEl.innerHTML = "";
    }

    if (tab === "settings") {
      listEl.hidden = true;
      settingsEl.hidden = false;
      const extras = listOtherRules();
      settingsEl.innerHTML = `
        <label>Where Agare runs</label>
        <p class="hint">Keep it off on sites you only skim. A longer highlight never paints over a shorter one already inside it.</p>
        <div class="gate">
          <div class="gate-row">
            <div>
              <p class="gate-title">This page</p>
              <p class="hint tight">Only the article you are on.</p>
            </div>
            <button class="switch${pageOn() ? " on" : ""}" data-act="page-toggle" type="button" role="switch" aria-checked="${pageOn()}"></button>
          </div>
          <div class="gate-row">
            <div>
              <p class="gate-title">This site</p>
              <p class="hint tight mono">${esc(host)}</p>
            </div>
            <button class="switch${hostOn() ? " on" : ""}" data-act="host-toggle" type="button" role="switch" aria-checked="${hostOn()}"></button>
          </div>
        </div>
        <p class="hint">New sites</p>
        <button class="choice${mode === "all" ? " on" : ""}" data-act="mode-all" type="button">
          <strong>Every site</strong>
          <span>Pause any page or domain you do not want.</span>
        </button>
        <button class="choice${mode === "ask" ? " on" : ""}" data-act="mode-ask" type="button">
          <strong>Only sites I turn on</strong>
          <span>Selecting text asks for this page or the whole domain.</span>
        </button>
        ${
          extras.length
            ? `<p class="hint">Other pages and sites</p><ul class="rules">${extras
                .map(
                  (r) =>
                    `<li><span class="mono">${esc(r.kind === "h" ? r.k : r.k.replace(/^https?:\/\//, ""))}</span> <em>${r.on ? "on" : "off"}</em> <button type="button" data-drop="${r.kind}:${esc(r.k)}">Clear</button></li>`,
                )
                .join("")}</ul>`
            : ""
        }
        <label>Highlight transparency</label>
        <p class="hint">Lower is more see-through. Applies on this machine.</p>
        <input type="range" min="18" max="88" value="${opacity}" />
        <p class="sample" style="background:color-mix(in srgb,#fff59e ${opacity}%, transparent)">Sample sentence with the current wash.</p>
        <div class="stack">
          <button class="btn block" data-act="export-all" type="button">Export all highlights</button>
          <button class="btn block" data-act="export-page" type="button">Export this page only</button>
          <button class="btn block" data-act="import" type="button">Import an Agare file</button>
        </div>
        <button class="danger" data-act="clear" type="button">Clear highlights on this page</button>
        <input type="file" accept="application/json,.json" hidden />
      `;
      return;
    }

    settingsEl.hidden = true;
    listEl.hidden = false;
    const shown = tab === "notes" ? notes : marks;
    let html = "";
    if (draft) {
      html += `<div class="composer">
        <p class="quote">“${esc(draft.e)}”</p>
        <textarea maxlength="1600" placeholder="Write a note for this sentence">${esc(draft.n || "")}</textarea>
        <div class="actions">
          <button class="btn ghost" data-act="cancel" type="button">Cancel</button>
          <button class="btn" data-act="save" type="button">Save note</button>
        </div>
      </div>`;
    }
    if (!shown.length && !draft) {
      html += `<p class="empty">${
        !pageOn()
          ? "Highlighting is off here. Select a sentence to turn Agare on for this page or this site."
          : tab === "notes"
            ? "No notes on this page yet. Select a sentence, pick a colour, then tap the pen."
            : "No highlights on this page. Select a sentence, then pick a colour."
      }</p>`;
    } else {
      html += shown
        .map((m) => {
          const c = L.COLORS[m.c] || L.COLORS[0];
          return `<article class="card" data-id="${esc(m.i)}">
            <span class="swatch" style="background:${c.f}"></span>
            <p class="quote">${esc(m.e)}</p>
            ${m.n ? `<p class="note" style="border-color:${c.n}">${esc(m.n)}</p>` : ""}
            <div class="row">
              <button class="icon-btn" data-act="edit" type="button" aria-label="Edit note">✎</button>
              <button class="icon-btn" data-act="del" type="button" aria-label="Remove">✕</button>
            </div>
          </article>`;
        })
        .join("");
    }
    listEl.innerHTML = html;
  };

  shadow.querySelector(".close").addEventListener("click", () => panel.classList.remove("open"));
  shadow.querySelector(".tabs").addEventListener("click", (e) => {
    const t = e.target.closest(".tab");
    if (!t) return;
    tab = t.dataset.tab;
    render();
  });

  pausedEl.addEventListener("click", (e) => {
    const act = e.target.closest("[data-act]");
    if (!act) return;
    if (act.dataset.act === "on-page") turnOn("page");
    if (act.dataset.act === "on-host") turnOn("host");
  });

  listEl.addEventListener("click", (e) => {
    const act = e.target.closest("[data-act]");
    const card = e.target.closest(".card");
    if (act && act.dataset.act === "save") {
      const ta = listEl.querySelector("textarea");
      if (draft && ta) {
        const n = ta.value.trim().slice(0, L.MAX_N);
        if (n) draft.n = n;
        else delete draft.n;
        draft = null;
        paintMarks();
        persistPage();
        render();
      }
      return;
    }
    if (act && act.dataset.act === "cancel") {
      draft = null;
      render();
      return;
    }
    if (!card) return;
    const m = marks.find((x) => x.i === card.dataset.id);
    if (!m) return;
    if (act && act.dataset.act === "del") {
      marks = marks.filter((x) => x.i !== m.i);
      if (draft && draft.i === m.i) draft = null;
      if (tb && tb.id === m.i) hideToolbar();
      paintMarks();
      persistPage();
      render();
      return;
    }
    if (act && act.dataset.act === "edit") {
      openNote(m);
      return;
    }
    const el = document.querySelector(`span.lumen-hl[data-id="${CSS.escape(m.i)}"]`);
    if (el) el.scrollIntoView({ behavior: "smooth", block: "center" });
  });

  const download = (name, data) => {
    const blob = new Blob([JSON.stringify(data)], { type: "application/json" });
    const a = document.createElement("a");
    a.href = URL.createObjectURL(blob);
    a.download = name;
    a.click();
    setTimeout(() => URL.revokeObjectURL(a.href), 1000);
  };

  const exportAll = async () => {
    const all = await storageGet(null);
    const p = {};
    for (const [k, v] of Object.entries(all)) {
      if (!k.startsWith("lumen.p.") || !v || !v.u || !Array.isArray(v.h)) continue;
      p[v.u] = v.h.map(L.clampMark).filter(Boolean);
    }
    download("Agare-highlights.json", { app: "agare", v: 1, a: opacity, c: pen, m: mode, g: gate, p });
  };

  const importFile = async (file) => {
    let data;
    try { data = JSON.parse(await file.text()); } catch { return; }
    if (!data || (data.app !== "agare" && data.app !== "lumen") || !data.p) return;
    if (typeof data.a === "number") opacity = data.a;
    if (Number.isInteger(data.c)) pen = data.c;
    if (data.m === "ask" || data.m === "all") mode = data.m;
    await persistSettings();
    if (data.g) {
      const incoming = L.clampGate(data.g);
      gate = { p: { ...gate.p, ...incoming.p }, h: { ...gate.h, ...incoming.h } };
      await persistGate();
    }
    for (const [url, raw] of Object.entries(data.p)) {
      if (!Array.isArray(raw) || typeof url !== "string") continue;
      const key = L.storeKey(url);
      const bag = await storageGet(key);
      const prev = Array.isArray(bag[key] && bag[key].h) ? bag[key].h.map(L.clampMark).filter(Boolean) : [];
      const seen = new Set(prev.map((m) => m.e + "\0" + m.p));
      const merged = prev.slice();
      for (const item of raw) {
        const m = L.clampMark(item);
        if (!m) continue;
        const sig = m.e + "\0" + m.p;
        if (seen.has(sig)) continue;
        seen.add(sig);
        merged.push(m);
      }
      if (merged.length) await storageSet({ [key]: { u: url, h: merged } });
    }
    await load();
  };

  settingsEl.addEventListener("input", (e) => {
    if (e.target.type === "range") {
      opacity = Number(e.target.value);
      applyOpacity();
      persistSettings();
      const sample = settingsEl.querySelector(".sample");
      if (sample) sample.style.background = `color-mix(in srgb,#fff59e ${opacity}%, transparent)`;
    }
  });
  settingsEl.addEventListener("click", (e) => {
    const drop = e.target.closest("[data-drop]");
    if (drop) {
      const raw = drop.getAttribute("data-drop") || "";
      const colon = raw.indexOf(":");
      const kind = raw.slice(0, colon);
      const key = raw.slice(colon + 1);
      if (kind === "h") {
        const h = { ...gate.h };
        delete h[key];
        gate = { p: { ...gate.p }, h };
      } else if (kind === "p") {
        const p = { ...gate.p };
        delete p[key];
        gate = { p, h: { ...gate.h } };
      }
      persistGate();
      paintMarks();
      render();
      return;
    }
    const act = e.target.closest("[data-act]");
    if (!act) return;
    if (act.dataset.act === "page-toggle") {
      gate = { p: { ...gate.p, [page]: pageOn() ? 0 : 1 }, h: { ...gate.h } };
      persistGate();
      hideToolbar();
      paintMarks();
      render();
      return;
    }
    if (act.dataset.act === "host-toggle") {
      const on = !hostOn();
      const p = { ...gate.p };
      delete p[page];
      gate = { p, h: { ...gate.h, [host]: on ? 1 : 0 } };
      persistGate();
      hideToolbar();
      paintMarks();
      render();
      return;
    }
    if (act.dataset.act === "mode-all") {
      mode = "all";
      persistSettings();
      paintMarks();
      render();
      return;
    }
    if (act.dataset.act === "mode-ask") {
      mode = "ask";
      gate = { p: { ...gate.p, [page]: 1 }, h: { ...gate.h } };
      persistSettings();
      persistGate();
      paintMarks();
      render();
      return;
    }
    if (act.dataset.act === "export-all") exportAll();
    if (act.dataset.act === "export-page") {
      download("Agare-page.json", { app: "agare", v: 1, a: opacity, c: pen, m: mode, g: gate, p: { [page]: marks } });
    }
    if (act.dataset.act === "import") {
      const f = settingsEl.querySelector('input[type="file"]');
      f.value = "";
      f.click();
    }
    if (act.dataset.act === "clear") {
      marks = [];
      draft = null;
      L.unwrapAll(root);
      persistPage();
      render();
    }
  });
  settingsEl.addEventListener("change", (e) => {
    if (e.target.files && e.target.files[0]) importFile(e.target.files[0]);
  });

  api.runtime.onMessage.addListener((msg) => {
    if (!msg || !msg.type) return;
    if (msg.type === "lumen:toggle") panel.classList.toggle("open");
    if (msg.type === "lumen:highlight") {
      if (!pageOn()) turnOn("page");
      paint(pen, false);
    }
    if (msg.type === "lumen:note") {
      if (!pageOn()) turnOn("page");
      paint(pen, true);
    }
    if (msg.type === "lumen:icon-query") syncIcon();
    render();
  });

  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape") {
      panel.classList.remove("open");
      hideToolbar();
      hideBubble();
    }
  });

  setInterval(() => {
    if (location.href !== lastUrl) {
      lastUrl = location.href;
      hideToolbar();
      load();
    }
  }, 700);

  load();
})();
