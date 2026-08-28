# Agare

A Safari extension for you to freely highlight and note whatever you want. Highlights never leave your local machine unless you export them.

## Install (Mac)

Same steps as [the Pages site](https://yvinc.github.io/agare-web-highlighter/). Download **[Agare.app.zip](https://github.com/yvinc/agare-web-highlighter/releases/latest/download/Agare.app.zip)** from [Releases](https://github.com/yvinc/agare-web-highlighter/releases/latest).

1. **Privacy & Security**  
   Unzip the latest release and drag Agare into Applications. Double-click it. If Mac says it can’t be opened: **System Settings → Privacy & Security**, scroll to the bottom, click **Open Anyway**, confirm, then open Agare again.

2. **Set up with Xcode**  
   Safari only keeps an extension on if it is signed. Set up with Xcode signs Agare with a free Apple ID on this Mac, so the app can be shared and used at no cost, and Safari keeps Agare on. First time on this Mac: in Xcode, Settings → Accounts → add your free Apple ID. Then in the Agare window click **Set up with Xcode…**. The helper stamps that Team on Agare and AgareExtension, builds, and registers the extension (Safari will quit once).

3. **Turn it on in Safari**  
   Safari → Settings → Extensions → turn on **Agare**. If it is missing, run Set up with Xcode again and wait for Safari to reopen.

### Permissions for Set up with Xcode

1. **Open Anyway** — System Settings → Privacy & Security, so the downloaded Agare.app can launch.
2. **Xcode** — installed from the App Store, opened once (licence). A free Apple ID in Xcode → Settings → Accounts.
3. **Terminal in Accessibility** — System Settings → Privacy & Security → Accessibility, turn on Terminal so the helper can choose Personal Team in Xcode. **Then restart Set up with Xcode.**
4. **Automation** — if asked, allow Terminal to control Xcode and System Events.
5. **Safari** — will quit once while the extension registers. After that: Safari → Settings → Extensions → turn on Agare.


This extension includes the following key features:

1.  Colours: Six inks (`#fff59e` lemon, `#fa9442` tangerine, `#a3ad00` olive, `#de4500` ember, `#96bfe6` sky, `#bf36e0` violet) with a transparency slider in `Settings`.
2.  Note-taking: Noted sentences take a deeper underline in the same ink; hover shows the note.
3.  A side panel: A list of highlights in the current page you're on only. It contains highlighted notes separately. `Settings` can be found here.
    - Double-click any highlighted text to open the side panel.
4.  Overlaying highlights: A longer highlight never paints over a shorter one already inside it, unlike how highlight works in other apps.
5.  Exportable highlights: Highlights stay in the extension’s sandboxed `storage.local`. They never leave the machine unless you export a JSON file. That file is how you move them between Macs freely!
6.  Toolbar popup:
    - Select a sentence, pick a colour to highlight.

    - To make a note: tap the pen in the same popup to write a note.

    - The bin removes a highlight; `Remove note` in the composer clears only the note.

    - Click an existing highlight to re-select its colour.

New installs stay off until you turn on **this page** or **this site**, so Agare will not mark every tab you open. Settings can switch that to “every site, pause the ones I don’t want.”

**Agare** is a play on 召し上がれ (*me-shi-a-ga-re*): please enjoy your meal. Mark what you take in while you read =)

## Storage

- One settings blob (`lumen.s`): opacity, last pen, and site mode (`all` or `ask`).
- One gate blob (`lumen.g`): page and host on/off flags. A page flag wins over its host; missing flags follow the site mode.
- One compact blob per page (`lumen.p.<hash>`): `{ u: pageKey, h: marks }`.
- A mark is `{ i, c, e, p, s, t, n? }` — colour as `0–5`, 24-character prefix/suffix for restore, note omitted when empty.
- Tracking query parameters are stripped from the page key. Hash fragments are ignored.
- A longer highlight never wraps text already inside a shorter one, so inner ink is not overpainted.

Export writes `Agare-highlights.json` (highlights, opacity, site mode, and on/off rules). Import merges by quote (exact + prefix); it does not upload anywhere. Older `Lumen-highlights.json` files still import.

## Licence

CC BY-NC 4.0. Written for personal use.
