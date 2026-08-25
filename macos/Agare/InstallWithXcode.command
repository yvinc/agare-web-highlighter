#!/bin/zsh
# Detects the free Xcode Apple ID team, stamps it on Agare + AgareExtension, then builds.
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

TEAM_INFO="$(python3 - <<'PY'
import re, subprocess

def teams_from_xcode():
    try:
        raw = subprocess.check_output(
            ["defaults", "read", "com.apple.dt.Xcode", "IDEProvisioningTeams"],
            text=True, stderr=subprocess.DEVNULL,
        )
    except subprocess.CalledProcessError:
        return []
    blocks = re.split(r"\{", raw)
    found = []
    for b in blocks:
        tid = re.search(r"teamID\s*=\s*([A-Z0-9]{10})", b)
        if not tid:
            continue
        name = re.search(r'teamName\s*=\s*"([^"]+)"', b)
        free = bool(re.search(r"isFreeTeamTeam\s*=\s*1", b))
        found.append((tid.group(1), name.group(1) if name else "", free))
    # unique, free first
    seen, out = set(), []
    for row in sorted(found, key=lambda r: (not r[2], r[0])):
        if row[0] in seen:
            continue
        seen.add(row[0])
        out.append(row)
    return out

def team_from_identities():
    try:
        out = subprocess.check_output(
            ["security", "find-identity", "-p", "codesigning", "-v"],
            text=True, stderr=subprocess.DEVNULL,
        )
    except subprocess.CalledProcessError:
        return ""
    for line in out.splitlines():
        if "Apple Development" not in line or "CSSMERR" in line:
            continue
        m = re.search(r"\(([A-Z0-9]{10})\)", line)
        if m:
            return m.group(1)
    return ""

def last_selected():
    try:
        raw = subprocess.check_output(
            ["defaults", "read", "com.apple.dt.Xcode", "IDELastSelectedProvisioningTeam"],
            text=True, stderr=subprocess.DEVNULL,
        ).strip().strip('"')
    except subprocess.CalledProcessError:
        return ""
    return raw if re.fullmatch(r"[A-Z0-9]{10}", raw) else ""

teams = teams_from_xcode()
last = last_selected()
chosen = None
for tid, name, free in teams:
    if last and tid == last:
        chosen = (tid, name, free)
        break
if chosen is None and teams:
    chosen = teams[0]
if chosen is None:
    ident = team_from_identities()
    if ident:
        chosen = (ident, "", True)

if not chosen:
    print("")
else:
    tid, name, free = chosen
    label = name or tid
    kind = "free" if free else "paid"
    print(f"{tid}\t{label}\t{kind}")
PY
)"

if [[ -z "$TEAM_INFO" ]]; then
  open -a Xcode
  say "Xcode has no Apple ID yet. In Xcode: Settings (⌘,) → Accounts → + → Apple ID. Sign in with your free iCloud account (not the paid Developer Program). Then click Set up with Xcode again."
  exit 0
fi

TEAM="${TEAM_INFO%%$'\t'*}"
REST="${TEAM_INFO#*$'\t'}"
TEAM_NAME="${REST%%$'\t'*}"
KIND="${REST##*$'\t'}"
LABEL="$TEAM"
if [[ -n "$TEAM_NAME" && "$TEAM_NAME" != "$TEAM" ]]; then
  LABEL="$TEAM_NAME ($TEAM)"
fi

confirm "Agare will sign both the app and the Safari extension with your Xcode team:
${LABEL}

No paid Developer Program is required. Safari will quit once after the build. Continue?" "Sign and build"

rm -rf "$DEST"
ditto "$KIT" "$DEST"
PROJ="$DEST/macos/Agare.xcodeproj"
test -d "$PROJ"

python3 - "$PROJ/project.pbxproj" "$TEAM" <<'PY'
import re, sys
path, team = sys.argv[1], sys.argv[2]
if not re.fullmatch(r"[A-Z0-9]{10}", team):
    raise SystemExit(f"bad team: {team}")
text = open(path).read()
text = re.sub(r"\n\t+DEVELOPMENT_TEAM = [^;]+;", "", text)
text = text.replace(
    "CODE_SIGN_STYLE = Automatic;",
    "CODE_SIGN_STYLE = Automatic;\n\t\t\t\tDEVELOPMENT_TEAM = %s;" % team,
)
text = re.sub(r"\n\t+DevelopmentTeam = [^;]+;", "", text)
text = text.replace(
    "ProvisioningStyle = Automatic;",
    "ProvisioningStyle = Automatic;\n\t\t\t\t\t\tDevelopmentTeam = %s;" % team,
)
open(path, "w").write(text)
print("stamped", team)
PY

# Do not open Xcode during the build — it locks the project and breaks signing.
cd "$DEST/macos"
LOG="$DEST/build.log"
set +e
xcodebuild -project Agare.xcodeproj -scheme Agare -configuration Debug \
  -destination "generic/platform=macOS" \
  -derivedDataPath "$DEST/DerivedData" \
  DEVELOPMENT_TEAM="$TEAM" \
  CODE_SIGN_STYLE=Automatic \
  CODE_SIGNING_ALLOWED=YES \
  CODE_SIGNING_REQUIRED=YES \
  ENABLE_HARDENED_RUNTIME=YES \
  -allowProvisioningUpdates \
  build >"$LOG" 2>&1
STATUS=$?
set -e

if [[ $STATUS -ne 0 ]]; then
  open "$PROJ"
  TAIL="$(tail -n 12 "$LOG" | tr -d '\r' | python3 -c 'import sys; print(sys.stdin.read()[:900])')"
  say "Automatic signing did not finish. The project is open in Xcode.

Confirm both Agare and AgareExtension show Team ${LABEL} under Signing & Capabilities, then press Run (▶).

Last build lines:
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
say "Signed with ${LABEL} and installed at ${INSTALLED}. Safari → Settings → Extensions → turn on Agare."
