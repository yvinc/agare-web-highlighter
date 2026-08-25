# Install Agare

Friends only need **Agare.app.zip** from the [latest Release](https://github.com/yvinc/agare-web-highlighter/releases/latest).

The Pages site is **[yvinc.github.io/agare-web-highlighter](https://yvinc.github.io/agare-web-highlighter/)**.

## For friends

1. Download **Agare.app.zip**. Unzip. Drag **Agare** into **Applications**.
2. Open Agare. If Mac says it can’t be opened: **System Settings → Privacy & Security**, scroll to the bottom, click **Open Anyway**, then open Agare again.
3. First time: in Xcode, Settings → Accounts → add your free Apple ID. Then **Set up with Xcode…**. The helper stamps that Team on both targets, builds, and registers Agare in Safari.
4. Safari → Settings → Extensions → turn on **Agare**.

If Agare is not listed, quit Safari (Safari menu → Quit Safari), open Agare again, then check Extensions.

Keep only one Agare.app. Delete extras in `/Applications` and `~/Applications`. After a rebuild: tick **Allow unsigned extensions**, then run `pluginkit` is handled by the helper.

## If Agare vanished from Safari after a reinstall

1. Safari menu → **Quit Safari**.
2. Delete **every** Agare.app (`/Applications`, `~/Applications`, and Xcode’s Products folder).
3. Open the Agare you just built (the helper puts it in `~/Applications`).
4. Safari → Settings → Advanced → **Show features for web developers**.
5. Developer → **Allow unsigned extensions**.
6. Extensions → Agare.

Safari hides unsigned extensions until step 5, and it forgets that tick when Safari quits. An old Agare.app still running will steal the new build (same bundle id) — quit all Agare windows first.

## For you, once

Pages: GitHub → Settings → Pages → Deploy from branch → `main` / `/docs`. Open [https://yvinc.github.io/agare-web-highlighter/](https://yvinc.github.io/agare-web-highlighter/).

To attach a new app: **Actions → Release Agare.app → Run workflow** on the tag, or push a new `v*` tag.

Source: [github.com/yvinc/agare-web-highlighter](https://github.com/yvinc/agare-web-highlighter)
