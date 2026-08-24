const api = globalThis.browser ?? globalThis.chrome;

const ICON_ON = { 16: "icons/16.png", 32: "icons/32.png", 48: "icons/48.png" };
const ICON_OFF = { 16: "icons/off-16.png", 32: "icons/off-32.png", 48: "icons/off-48.png" };

function send(tabId, msg) {
  try {
    const r = api.tabs.sendMessage(tabId, msg);
    if (r && typeof r.catch === "function") r.catch(() => {});
  } catch (_) { /* tab has no content script */ }
}

function setTabIcon(tabId, on) {
  if (tabId == null || !api.action) return;
  const path = on ? ICON_ON : ICON_OFF;
  try {
    const r = api.action.setIcon({ tabId, path });
    if (r && typeof r.catch === "function") r.catch(() => {});
  } catch (_) { /* Safari may reject setIcon on some tabs */ }
  try {
    api.action.setTitle({
      tabId,
      title: on ? "Agare is on for this page" : "Agare is off on this page",
    });
  } catch (_) { /* title optional */ }
}

function menus() {
  const make = () => {
    api.contextMenus.create({
      id: "lumen-hl",
      title: "Highlight with Agare",
      contexts: ["selection"],
    });
    api.contextMenus.create({
      id: "lumen-note",
      title: "Add Agare note",
      contexts: ["selection"],
    });
  };
  try {
    if (api.contextMenus.removeAll) {
      api.contextMenus.removeAll(() => make());
    } else make();
  } catch (_) {
    try { make(); } catch (__) { /* menus unavailable */ }
  }
}

if (api.runtime && api.runtime.onInstalled) {
  api.runtime.onInstalled.addListener(menus);
}
menus();

if (api.action && api.action.onClicked) {
  api.action.onClicked.addListener((tab) => {
    if (tab && tab.id != null) send(tab.id, { type: "lumen:toggle" });
  });
}

if (api.contextMenus && api.contextMenus.onClicked) {
  api.contextMenus.onClicked.addListener((info, tab) => {
    if (!tab || tab.id == null) return;
    send(tab.id, {
      type: info.menuItemId === "lumen-note" ? "lumen:note" : "lumen:highlight",
    });
  });
}

if (api.runtime && api.runtime.onMessage) {
  api.runtime.onMessage.addListener((msg, sender) => {
    if (!msg || msg.type !== "lumen:icon") return;
    const tabId = sender && sender.tab && sender.tab.id;
    if (tabId != null) setTabIcon(tabId, !!msg.on);
  });
}

if (api.tabs && api.tabs.onActivated) {
  api.tabs.onActivated.addListener((info) => {
    send(info.tabId, { type: "lumen:icon-query" });
  });
}

if (api.tabs && api.tabs.onUpdated) {
  api.tabs.onUpdated.addListener((tabId, change) => {
    if (change.status === "complete" || change.url) send(tabId, { type: "lumen:icon-query" });
  });
}
