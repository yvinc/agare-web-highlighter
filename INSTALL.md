# Install Agare

Friends only need the Mac app. There is one download: **Agare.app.zip**.

## For friends

1. Open the [latest Release](releases/latest) (or the Pages site) and download **Agare.app.zip**.
2. Unzip. Drag **Agare** into **Applications**.
3. Right-click Agare → **Open** (macOS asks once).
4. Click **Turn on in Safari…** and enable Agare.
5. If it is missing: Safari → Settings → Developer → Allow unsigned extensions, then repeat step 4.

That is the whole install. No Xcode.

Safari may ask you to allow unsigned extensions again after it quits. That is Apple, not Agare. The app stays in Applications.

## For you, once

1. Put `YOUR-USER/agare` in `docs/repo.json`.
2. Push the files listed below.
3. GitHub → Settings → Pages → `main` / `/docs`.
4. Settings → Actions → allow Actions.
5. Tag a release:

```bash
git tag v1.0.0
git push origin v1.0.0
```

Wait for the green check on the Actions tab. That job builds **Agare.app.zip** on a Mac runner and attaches it to the Release. Send friends:

- the Pages URL, or
- `https://github.com/YOUR-USER/agare/releases/latest`

Do not send the source folder.
