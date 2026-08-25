#!/usr/bin/osascript -l JavaScript
// Clicks Team → “(Personal Team)” on Agare and AgareExtension.
// Requires: System Settings → Privacy & Security → Accessibility → Terminal (or iTerm).

function run() {
  const se = Application("System Events");
  const app = Application.currentApplication();
  app.includeStandardAdditions = true;

  if (!se.UIElementsEnabled()) return "NO_AX";

  const procs = se.processes.whose({ name: "Xcode" });
  if (!procs.length) return "NO_XCODE";
  const proc = procs[0];
  proc.frontmost = true;
  app.delay(1.0);

  const safe = (fn, d) => {
    try {
      return fn();
    } catch (e) {
      return d;
    }
  };

  const wins = proc.windows();
  let win = null;
  for (let i = 0; i < wins.length; i++) {
    const n = String(safe(() => wins[i].name(), ""));
    if (/agare/i.test(n)) {
      win = wins[i];
      break;
    }
  }
  if (!win && wins.length) win = wins[0];
  if (!win) return "NO_WIN";

  const contents = () => safe(() => win.entireContents(), []);

  const clickNamed = (label) => {
    const ui = contents();
    for (let i = 0; i < ui.length; i++) {
      const el = ui[i];
      const name = String(safe(() => el.name(), ""));
      const val = String(safe(() => el.value(), ""));
      if (name !== label && val !== label) continue;
      try {
        el.click();
        app.delay(0.45);
        return true;
      } catch (e) {}
    }
    return false;
  };

  const pickPersonal = () => {
    const ui = contents();
    for (let i = 0; i < ui.length; i++) {
      const el = ui[i];
      const name = String(safe(() => el.name(), ""));
      const role = String(safe(() => el.role(), ""));
      if (
        name === "Signing & Capabilities" &&
        /Button|Radio|Tab|CheckBox|PopUp/.test(role)
      ) {
        try {
          el.click();
          app.delay(0.5);
        } catch (e) {}
        break;
      }
    }
    const ui2 = contents();
    let popup = null;
    for (let i = 0; i < ui2.length; i++) {
      const el = ui2[i];
      if (String(safe(() => el.role(), "")) !== "AXPopUpButton") continue;
      const blob = (
        String(safe(() => el.value(), "")) +
        " " +
        String(safe(() => el.description(), "")) +
        " " +
        String(safe(() => el.name(), ""))
      ).toLowerCase();
      if (blob.includes("personal team") && !blob.includes("unknown")) {
        return "ALREADY";
      }
      if (
        blob.includes("unknown") ||
        blob.includes("none") ||
        blob.includes("team") ||
        blob.includes("add an account")
      ) {
        popup = el;
        if (blob.includes("unknown") || blob.includes("none")) break;
      }
    }
    if (!popup) return "NO_POPUP";
    try {
      popup.click();
    } catch (e) {
      return "NO_CLICK";
    }
    app.delay(0.45);
    let items = [];
    try {
      items = popup.menus[0].menuItems();
    } catch (e) {
      return "NO_MENU";
    }
    for (let i = 0; i < items.length; i++) {
      const n = String(safe(() => items[i].name(), ""));
      if (/personal team/i.test(n)) {
        items[i].click();
        app.delay(0.9);
        return "OK:" + n;
      }
    }
    return "NO_PERSONAL";
  };

  const a = [];
  clickNamed("Agare");
  a.push("Agare=" + pickPersonal());
  clickNamed("AgareExtension");
  a.push("Ext=" + pickPersonal());
  clickNamed("Agare");
  a.push("Agare2=" + pickPersonal());
  return a.join(";");
}
