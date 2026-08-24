# Agare

A personal Safari Web Extension for sentence highlighting and notes.
## Install (Mac)

1. Download **[Agare.app.zip](releases/latest/download/Agare.app.zip)** from [Releases](releases/latest).
2. Unzip, then drag **Agare** into **Applications**.
3. Right-click Agare → **Open** (the first time only).
4. Click **Turn on in Safari…** and enable it.

If Safari hides it: Safari → Settings → Developer → Allow unsigned extensions, then try again.

# Features
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

[CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/)
Attribution-NonCommercial-ShareAlike 4.0 International

Written for personal use.