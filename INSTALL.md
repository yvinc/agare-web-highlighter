# Install Agare

Friends only need **Agare.app.zip**.

## For friends

1. Download **Agare.app.zip** from the [latest Release](releases/latest) (or the Pages site). Unzip. Drag **Agare** into **Applications**.
2. Open Agare. If Mac says it can’t be opened: **System Settings → Privacy & Security**, scroll to the bottom, click **Open Anyway**, then open Agare again.
3. Open **Safari**. Open Settings (⌘,).
4. **Advanced** — tick **Show features for web developers**. That shows the Developer tab.
5. **Developer** — tick **Allow unsigned extensions**. Enter your password if asked.
6. **Extensions** — turn on **Agare**.

If Agare is not listed, quit Safari (Safari menu → Quit Safari), open Agare again, then check Extensions.

Safari turns off “Allow unsigned extensions” when it quits. Tick it again the next time you launch Safari.

If Xcode is already on the Mac: open Agare and click **Set up with Xcode…**. Confirm the prompts. That copies the project, opens it, and can try a build. In Xcode, pick your Team, then Run. A free Apple ID still may need the unsigned tick after Safari quits — only a paid Developer ID (notarized app) makes that stick for friends.

The **Show Extensions list** button in Agare only works after step 5. Before that, Safari hides the extension and the button does nothing.

## For you, once

1. Put `YOUR-USER/agare` in `docs/repo.json`.
2. Push `macos/`, `docs/`, `.github/workflows/release.yml`, and `INSTALL.md`.
3. Pages: Settings → Pages → `main` / `/docs`.
4. Settings → Actions → allow Actions.
5. Tag a new version, **or** run the Action by hand:

```bash
git tag v1.0.2
git push origin v1.0.2
```

If a tag already exists: **Actions → Release Agare.app → Run workflow** → type that exact tag. It attaches `Agare.app.zip` to the existing Release.

Send friends the Pages URL or the Release page — not the source folder.
