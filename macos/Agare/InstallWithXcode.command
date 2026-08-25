#!/bin/zsh
# Uses only teams from Xcode → Settings → Accounts (never a leftover keychain cert).
set -euo pipefail
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin"

APP="$(cd "$(dirname "$0")/../.." && pwd)"
KIT="$APP/Contents/Resources/Kit"
DEST="$HOME/Agare-build"
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
  say "Install Xcode from the App Store, open it once (accept the licence), then click Set up with Xcode again."
  exit 1
fi

if ! xcodebuild -version >/dev/null 2>&1; then
  open -a Xcode
  say "Open Xcode once to finish its setup (accept the licence), then click Set up with Xcode again."
  exit 1
fi

TEAMS_TSV="$(python3 - <<'PY'
import json, os, plistlib, re, subprocess, tempfile
from pathlib import Path

def load_prefs():
    path = Path.home() / "Library/Preferences/com.apple.dt.Xcode.plist"
    if path.exists():
        try:
            with path.open("rb") as f:
                return plistlib.load(f)
        except Exception:
            pass
    tmp = Path(tempfile.gettempdir()) / "agare-xcode.json"
    try:
        subprocess.check_call(
            ["defaults", "export", "com.apple.dt.Xcode", str(tmp.with_suffix(".plist"))],
            stderr=subprocess.DEVNULL,
        )
        subprocess.check_call(
            ["plutil", "-convert", "json", "-o", str(tmp), str(tmp.with_suffix(".plist"))],
            stderr=subprocess.DEVNULL,
        )
        return json.loads(tmp.read_text())
    except Exception:
        return {}

def walk(obj, out):
    if isinstance(obj, dict):
        tid = obj.get("teamID") or obj.get("teamId")
        if isinstance(tid, str) and re.fullmatch(r"[A-Z0-9]{10}", tid):
            name = obj.get("teamName") or obj.get("name") or ""
            free = bool(
                obj.get("isFreeTeamTeam")
                or obj.get("isFreeProvisioningTeam")
                or obj.get("isPersonalTeam")
            )
            out.append((tid, str(name), free))
        for v in obj.values():
            walk(v, out)
    elif isinstance(obj, list):
        for v in obj:
            walk(v, out)

prefs = load_prefs()
found = []
walk(prefs.get("IDEProvisioningTeams", {}), found)
# unique, personal/free first
seen, rows = set(), []
for tid, name, free in sorted(found, key=lambda r: (not r[2], r[1], r[0])):
    if tid in seen:
        continue
    seen.add(tid)
    rows.append((tid, name, free))
for tid, name, free in rows:
    print(f"{tid}\t{name}\t{'free' if free else 'paid'}")
PY
)"

if [[ -z "$TEAMS_TSV" ]]; then
  open -a Xcode
  say "Xcode Accounts has no Team yet. Xcode → Settings (⌘,) → Accounts → + → Apple ID. Sign in with your free iCloud account. Click the account and wait until a Team name appears under it. Then click Set up with Xcode again.

A leftover certificate in Keychain is not enough — the Apple ID must show a Team in Accounts."
  exit 0
fi

LIST="$(print -r -- "$TEAMS_TSV" | awk -F'\t' '{printf("• %s %s%s\n", $2==""?$1:$2, $1, $3=="free"?" (free)":"")}')"

confirm "Agare will use your Xcode Accounts team(s) to sign both Agare and AgareExtension (Apple Development, no paid program):

${LIST}

Safari will quit once after a successful build. Continue?" "Sign and build"

rm -rf "$DEST"
ditto "$KIT" "$DEST"
PROJ="$DEST/macos/Agare.xcodeproj"
test -d "$PROJ"
rm -rf "$PROJ/xcuserdata" "$PROJ/project.xcworkspace/xcuserdata" 2>/dev/null || true

stamp_team() {
  local team="$1"
  python3 - "$PROJ/project.pbxproj" "$team" <<'PY'
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
}

cd "$DEST/macos"
LOG="$DEST/build.log"
: >"$LOG"
STATUS=1
USED_TEAM=""
USED_NAME=""

while IFS=$'\t' read -r TEAM TEAM_NAME KIND; do
  [[ -z "$TEAM" ]] && continue
  stamp_team "$TEAM"
  {
    echo "===== team $TEAM ($TEAM_NAME $KIND) ====="
    xcodebuild -project Agare.xcodeproj -scheme Agare -configuration Debug \
      -destination "generic/platform=macOS" \
      -derivedDataPath "$DEST/DerivedData" \
      DEVELOPMENT_TEAM="$TEAM" \
      CODE_SIGN_STYLE=Automatic \
      CODE_SIGN_IDENTITY="Apple Development" \
      CODE_SIGNING_ALLOWED=YES \
      CODE_SIGNING_REQUIRED=YES \
      ENABLE_HARDENED_RUNTIME=YES \
      -allowProvisioningUpdates \
      build
  } >>"$LOG" 2>&1
  STATUS=$?
  if [[ $STATUS -eq 0 ]]; then
    USED_TEAM="$TEAM"
    USED_NAME="${TEAM_NAME:-$TEAM}"
    break
  fi
done <<<"$TEAMS_TSV"

if [[ $STATUS -ne 0 ]]; then
  open -a Xcode
  open "$PROJ"
  TAIL="$(tail -n 16 "$LOG" | tr -d '\r' | python3 -c 'import sys; print(sys.stdin.read()[:1100])')"
  say "Xcode could not sign with the Team(s) on this Mac:

${LIST}

Fix: Xcode → Settings → Accounts. Select your Apple ID. If it says session expired, sign in again. The account must list a Team (your name is fine — that is the free personal team). Then click Set up with Xcode again.

Do not pick a leftover Keychain certificate. Last build lines:

${TAIL}"
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
say "Signed with ${USED_NAME} (${USED_TEAM}) using Apple Development and installed at ${INSTALLED}. Safari → Settings → Extensions → turn on Agare."
