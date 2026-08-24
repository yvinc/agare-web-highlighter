#!/bin/zsh
# Always copies the Agare Xcode project, opens it, then tries a free Apple Development sign.
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

confirm "Agare will copy its Xcode project to ${DEST} and open it. You sign with a free Apple ID — no paid Developer Program. Continue?" "Open project"

rm -rf "$DEST"
ditto "$KIT" "$DEST"
PROJ="$DEST/macos/Agare.xcodeproj"
GUIDE="$DEST/macos/Agare/HowToSign.txt"
test -d "$PROJ"

open -e "$GUIDE" 2>/dev/null || open "$GUIDE"
open "$PROJ"

TEAM="$(python3 - <<'PY'
import re, subprocess, sys
def from_identities():
    try:
        out = subprocess.check_output(["security", "find-identity", "-p", "codesigning", "-v"], text=True, stderr=subprocess.DEVNULL)
    except subprocess.CalledProcessError:
        return ""
    for line in out.splitlines():
        if "Apple Development" not in line or "CSSMERR" in line:
            continue
        m = re.search(r"\(([A-Z0-9]{10})\)", line)
        if m:
            return m.group(1)
    return ""

def from_xcode_accounts():
    try:
        raw = subprocess.check_output(["defaults", "read", "com.apple.dt.Xcode", "IDEProvisioningTeams"], text=True, stderr=subprocess.DEVNULL)
    except subprocess.CalledProcessError:
        return ""
    ids = re.findall(r"teamID\s*=\s*([A-Z0-9]{10})", raw)
    return ids[0] if ids else ""

print(from_identities() or from_xcode_accounts())
PY
)"

STEPS="In the Xcode window that just opened:

1. Xcode menu → Settings (⌘,) → Accounts → + → Apple ID.
   Sign in with your free iCloud Apple ID (not a paid Developer Program).

2. Left sidebar: click the blue Agare project icon at the top.
   Under TARGETS click Agare (the app icon). The scheme at the top should say Agare > My Mac.

3. Signing & Capabilities → tick Automatically manage signing → Team → your name.

4. Press the Play button ▶  (Product → Run).

5. Safari → Settings → Extensions → turn on Agare.

A file named HowToSign is also open with these steps."

if [[ -z "$TEAM" ]]; then
  say "$STEPS"
  exit 0
fi

# Team exists — try to build and register. If that fails, the project is already open for Run.
cd "$DEST/macos"
set +e
xcodebuild -project Agare.xcodeproj -scheme Agare -configuration Debug \
  -destination "platform=macOS" \
  -derivedDataPath "$DEST/DerivedData" \
  DEVELOPMENT_TEAM="$TEAM" \
  CODE_SIGN_IDENTITY="Apple Development" \
  CODE_SIGN_STYLE=Automatic \
  CODE_SIGNING_ALLOWED=YES \
  CODE_SIGNING_REQUIRED=YES \
  ENABLE_HARDENED_RUNTIME=YES \
  -allowProvisioningUpdates \
  build
STATUS=$?
set -e

if [[ $STATUS -ne 0 ]]; then
  say "Automatic signing could not finish. Follow the HowToSign steps in Xcode, then press Run (▶). That is what adds Agare to Safari."
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
say "Agare is installed at ${INSTALLED}. Safari → Settings → Extensions → turn on Agare."
