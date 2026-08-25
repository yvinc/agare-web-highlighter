#!/bin/zsh
# Automates Xcode Team → “(Personal Team)” on both targets, then builds.
set -euo pipefail
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin"

APP="$(cd "$(dirname "$0")/../.." && pwd)"
KIT="$APP/Contents/Resources/Kit"
DEST="$HOME/Agare-build"
PROJ="$DEST/macos/Agare.xcodeproj"
FAILFILE="$HOME/Library/Application Support/Agare/failed-teams.txt"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
EXT_ID="ca.agare.highlighter.extension"

say() {
  osascript - "$1" <<'APPLESCRIPT'
on run argv
  display dialog (item 1 of argv) buttons {"OK"} default button 1 with title "Agare"
end run
APPLESCRIPT
}

confirm() {
  osascript - "$1" "$2" <<'APPLESCRIPT'
on run argv
  display dialog (item 1 of argv) buttons {"Cancel", (item 2 of argv)} default button 2 with title "Agare"
end run
APPLESCRIPT
}

if [[ ! -d "$KIT/macos/Agare.xcodeproj" ]]; then
  say "This copy of Agare is missing its Xcode project. Download Agare.app from GitHub Releases again."
  exit 1
fi
if [[ ! -d /Applications/Xcode.app ]]; then
  open "macappstores://apps.apple.com/app/xcode/id497799835"
  say "Install Xcode from the App Store, open it once, then click Set up with Xcode again."
  exit 1
fi
if ! xcodebuild -version >/dev/null 2>&1; then
  open -a Xcode
  say "Open Xcode once to finish its setup (accept the licence), then click Set up with Xcode again."
  exit 1
fi

mkdir -p "$(dirname "$FAILFILE")"
touch "$FAILFILE"

if [[ ! -d "$PROJ" ]]; then
  rm -rf "$DEST"
  ditto "$KIT" "$DEST"
fi
test -d "$PROJ"

# Strip Keychain-cert team IDs that already failed as “Unknown Name”.
python3 - "$PROJ/project.pbxproj" "$FAILFILE" <<'PY'
import re, sys
pbx, fail = sys.argv[1], sys.argv[2]
bad = {l.strip() for l in open(fail) if l.strip()}
if not bad:
    raise SystemExit
text = open(pbx).read()
def keep(m):
    return "" if m.group(1) in bad else m.group(0)
text2 = re.sub(r"DEVELOPMENT_TEAM = ([A-Z0-9]{10});", keep, text)
text2 = re.sub(r"DevelopmentTeam = ([A-Z0-9]{10});", keep, text2)
if text2 != text:
    open(pbx, "w").write(text2)
PY

open "$PROJ"
sleep 2

# Official Accessibility permission popup (TCC). macOS will not let us click Allow for you.
AX_OK="$(osascript -l JavaScript <<'JS'
ObjC.import("ApplicationServices")
const opts = $.NSMutableDictionary.dictionary
opts.setObjectForKey(true, "AXTrustedCheckOptionPrompt")
$.AXIsProcessTrustedWithOptions(opts) ? "1" : "0"
JS
)"
if [[ "$AX_OK" != "1" ]]; then
  say "macOS is asking to allow Terminal to control Xcode (Accessibility). Click Allow on that popup, then Set up with Xcode again. Agare cannot turn that switch on by itself."
  exit 0
fi

PICK="$DEST/macos/Agare/PickPersonalTeam.applescript"
if [[ ! -f "$PICK" ]]; then
  PICK="$(dirname "$0")/PickPersonalTeam.applescript"
fi

confirm "Agare will choose your name (Personal Team) in Xcode for both targets and then build. Continue?" "Sign and build"

set +e
PICK_OUT="$(osascript "$PICK" 2>/dev/null)"
set -e

read_team() {
  python3 - "$PROJ/project.pbxproj" "$FAILFILE" "$HOME" <<'PY'
import plistlib, re, sys
from pathlib import Path
pbx, fail, home = Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3])
bad = {l.strip() for l in fail.read_text().splitlines() if l.strip()}

def add(tid, bucket):
    if re.fullmatch(r"[A-Z0-9]{10}", tid or "") and tid not in bad:
        bucket.append(tid)

found = []
text = pbx.read_text(errors="ignore") if pbx.exists() else ""
for tid in re.findall(r"DEVELOPMENT_TEAM = ([A-Z0-9]{10});", text):
    add(tid, found)
for tid in re.findall(r"DevelopmentTeam = ([A-Z0-9]{10});", text):
    add(tid, found)

# Free/personal team records Xcode caches after the dropdown has been used.
free = []
def walk(obj):
    if isinstance(obj, dict):
        tid = obj.get("teamID") or obj.get("teamId")
        name = str(obj.get("teamName") or obj.get("name") or "")
        is_free = bool(
            obj.get("isFreeTeamTeam")
            or obj.get("isFreeProvisioningTeam")
            or obj.get("isPersonalTeam")
            or "personal team" in name.lower()
        )
        if is_free:
            add(str(tid or ""), free)
        for v in obj.values():
            walk(v)
    elif isinstance(obj, list):
        for v in obj:
            walk(v)

roots = [
    home / "Library/Preferences/com.apple.dt.Xcode.plist",
]
roots += list((home / "Library/Developer/Xcode").glob("DeveloperPortal*"))
roots.append(home / "Library/Developer/Xcode/UserData")
for root in roots:
    if not root.exists():
        continue
    paths = [root] if root.is_file() else list(root.rglob("*.plist"))[:80]
    for path in paths:
        if path.is_dir():
            continue
        try:
            with path.open("rb") as f:
                walk(plistlib.load(f))
        except Exception:
            continue

# Prefer IDs Xcode just wrote, then cached personal teams.
ordered, seen = [], set()
for tid in found + free:
    if tid in seen:
        continue
    seen.add(tid)
    ordered.append(tid)
print(ordered[0] if ordered else "")
PY
}

TEAM=""
for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
  TEAM="$(read_team)"
  [[ -n "$TEAM" ]] && break
  sleep 1
done

if [[ -z "$TEAM" ]]; then
  say "Could not select Personal Team automatically (${PICK_OUT:-no UI result}).

In Xcode, on Agare and AgareExtension, open Team and click your name (Personal Team) — not red Unknown Name. Then Set up with Xcode again.

If macOS asked to control Xcode, click Allow and retry."
  exit 0
fi

python3 - "$PROJ/project.pbxproj" "$TEAM" <<'PY'
import re, sys
path, team = sys.argv[1], sys.argv[2]
text = open(path).read()
text = re.sub(r"\n\t+DEVELOPMENT_TEAM = [^;]+;", "", text)
text = re.sub(r"\n\t+CODE_SIGN_IDENTITY = [^;]+;", "", text)
text = text.replace(
    "CODE_SIGN_STYLE = Automatic;",
    "CODE_SIGN_STYLE = Automatic;\n\t\t\t\tDEVELOPMENT_TEAM = %s;\n\t\t\t\tCODE_SIGN_IDENTITY = \"Apple Development\";" % team,
)
text = re.sub(r"\n\t+DevelopmentTeam = [^;]+;", "", text)
text = text.replace(
    "ProvisioningStyle = Automatic;",
    "ProvisioningStyle = Automatic;\n\t\t\t\t\t\tDevelopmentTeam = %s;" % team,
)
open(path, "w").write(text)
PY

cd "$DEST/macos"
LOG="$DEST/build.log"
set +e
xcodebuild -project Agare.xcodeproj -scheme Agare -configuration Debug \
  -destination "generic/platform=macOS" \
  -derivedDataPath "$DEST/DerivedData" \
  CODE_SIGN_STYLE=Automatic \
  CODE_SIGN_IDENTITY="Apple Development" \
  CODE_SIGNING_ALLOWED=YES \
  CODE_SIGNING_REQUIRED=YES \
  ENABLE_HARDENED_RUNTIME=YES \
  -allowProvisioningUpdates \
  build >"$LOG" 2>&1
STATUS=$?
set -e

if [[ $STATUS -ne 0 ]]; then
  echo "$TEAM" >>"$FAILFILE"
  TAIL="$(tail -n 14 "$LOG" | tr -d '\r' | python3 -c 'import sys; print(sys.stdin.read()[:1000])')"
  if grep -q "No Account for Team" "$LOG"; then
    say "Xcode rejected ${TEAM} (that is the Unknown Name / Keychain cert). It is now ignored.

Run Set up with Xcode again. Allow control of Xcode if asked, so it can click your name (Personal Team) in the Team menu."
  else
    say "Build failed. UI picker: ${PICK_OUT:-?}
Last lines:
${TAIL}"
  fi
  exit 0
fi

BUILT="$DEST/DerivedData/Build/Products/Debug/Agare.app"
if [[ ! -d "$BUILT" ]]; then
  BUILT="$DEST/DerivedData/Build/Products/Release/Agare.app"
fi
test -d "$BUILT"
test -f "$BUILT/Contents/PlugIns/AgareExtension.appex/Contents/Resources/manifest.json"

killall Agare 2>/dev/null || true
osascript -e 'tell application "Safari" to quit' >/dev/null 2>&1 || true
sleep 0.8

rm -rf "$HOME/Applications/Agare.app"
mkdir -p "$HOME/Applications"
ditto "$BUILT" "$HOME/Applications/Agare.app"
INSTALLED="$HOME/Applications/Agare.app"
if [[ -w /Applications ]]; then
  rm -rf /Applications/Agare.app
  ditto "$BUILT" /Applications/Agare.app
  INSTALLED="/Applications/Agare.app"
fi

APPEX="$INSTALLED/Contents/PlugIns/AgareExtension.appex"
"$LSREGISTER" -f "$INSTALLED" >/dev/null 2>&1 || true
pluginkit -a "$APPEX" >/dev/null 2>&1 || true
pluginkit -e use -i "$EXT_ID" >/dev/null 2>&1 || true

defaults write com.apple.Safari IncludeDevelopMenu -bool true
defaults write com.apple.Safari AllowUnsignedExtensions -bool true
SAFARI_PREF="$HOME/Library/Containers/com.apple.Safari/Data/Library/Preferences/com.apple.Safari"
defaults write "$SAFARI_PREF" IncludeDevelopMenu -bool true
defaults write "$SAFARI_PREF" AllowUnsignedExtensions -bool true

open "$INSTALLED"
sleep 1
open -a Safari
say "Signed with Personal Team ${TEAM} and installed at ${INSTALLED}. Safari → Settings → Extensions → turn on Agare."
