# Install Agare

Friends only need **Agare.app.zip** from the [latest Release](https://github.com/yvinc/agare-web-highlighter/releases/latest).

The Pages site is **[yvinc.github.io/agare-web-highlighter](https://yvinc.github.io/agare-web-highlighter/)**.

## For friends

1. **Privacy & Security** — Unzip **Agare.app.zip**. Drag **Agare** into **Applications**. Double-click it. If Mac says it can’t be opened: **System Settings → Privacy & Security**, scroll to the bottom, click **Open Anyway**, then open Agare again.
2. **Set up with Xcode** — Safari only keeps an extension on if it is signed. Set up with Xcode signs Agare with a free Apple ID so the app can be shared and used at no cost. First time: Xcode → Settings → Accounts → add your free Apple ID, then **Set up with Xcode…**. Safari will quit once.
3. **Turn it on in Safari** — Safari → Settings → Extensions → turn on **Agare**. If it is missing, run Set up with Xcode again and wait for Safari to reopen.

Keep only one Agare.app. Delete extras in `/Applications` and `~/Applications`.

## If Agare vanished from Safari after a reinstall

1. Safari menu → **Quit Safari**.
2. Delete **every** Agare.app (`/Applications`, `~/Applications`, and Xcode’s Products folder).
3. Open the Agare you just built (the helper puts it in `~/Applications`).
4. Run **Set up with Xcode…** again, then Safari → Settings → Extensions → Agare.

An old Agare.app still running will steal the new build (same bundle id) — quit all Agare windows first.

## For you, once

Pages: GitHub → Settings → Pages → Deploy from branch → `main` / `/docs`. Open [https://yvinc.github.io/agare-web-highlighter/](https://yvinc.github.io/agare-web-highlighter/).

To attach a new app: **Actions → Release Agare.app → Run workflow** on the tag, or push a new `v*` tag.

Source: [github.com/yvinc/agare-web-highlighter](https://github.com/yvinc/agare-web-highlighter)
