#!/bin/zsh
# Signs Agare with this Mac’s Xcode team, installs it, and registers the Safari extension.
set -euo pipefail
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin"

APP="$(cd "$(dirname "$0")/../.." && pwd)"
KIT="$APP/Contents/Resources/Kit"
DEST="$HOME/Agare-build"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
EXT_ID="ca.agare.highlighter.extension"

say() {
  osascript -e "display dialog \"$1\" buttons {\"OK\"} default button 1 with title \"Agare\"" >/dev/null
}

confirm() {
  osascript -e "display dialog \"$1\" buttons {\"Cancel\", \"$2\"} default button 2 with title \"Agare\"" >/dev/null
}

if [[ ! -d "$KIT/macos/Agare.xcodeproj" && ! -f "$KIT/manifest.json" ]]; then
  say "This copy of Agare is missing its Xcode kit. Download Agare.app from GitHub Releases again."
  exit 1
fi

if [[ ! -d /Applications/Xcode.app ]]; then
  open "macappstores://apps.apple.com/app/xcode/id497799835"
  say "Install Xcode from the App Store, open it once, then click Set up with Xcode again."
  exit 1
fi

if ! xcodebuild -version >/dev/null 2>&1; then
  open -a Xcode
  say "Open Xcode once to finish its setup (accept the licence), then try again."
  exit 1
fi

TEAM="$(python3 - <<'PY'
import re, subprocess
out = subprocess.check_output(["security", "find-identity", "-p", "codesigning", "-v"], text=True, stderr=subprocess.DEVNULL)
for line in out.splitlines():
    if "Apple Development" not in line or "CSSMERR" in line:
        continue
    m = re.search(r"\(([A-Z0-9]{10})\)\"?\s*$", line.strip())
    if m:
        print(m.group(1))
        raise SystemExit
print("")
PY
)"

if [[ -z "$TEAM" ]]; then
  open -a Xcode
  say "Add a free Apple ID in Xcode (no paid Developer Program). Xcode → Settings → Accounts → + → Apple ID. Then Agare target → Signing & Capabilities → Team → that Apple ID → Run."
  exit 1
fi

confirm "Agare will sign with your free Apple Development certificate (team ${TEAM}), install Agare.app, and register it in Safari. No paid Developer Program. Safari will quit once so the extension can appear. Continue?" "Continue"

rm -rf "$DEST"
ditto "$KIT" "$DEST"
PROJ="$DEST/macos/Agare.xcodeproj"
if [[ ! -d "$PROJ" ]]; then
  say "The Xcode project is missing from this kit."
  exit 1
fi

cd "$DEST/macos"
set +e
xcodebuild -project Agare.xcodeproj -scheme Agare -configuration Release \
  -destination "generic/platform=macOS" \
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
  open "$PROJ"
  say "Signing build failed. In Xcode → Settings → Accounts, add your free Apple ID. Agare target → Signing & Capabilities → Team → that Apple ID, then press Run."
  exit 1
fi

BUILT="$DEST/DerivedData/Build/Products/Release/Agare.app"
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

# Match Xcode Run: Safari’s Develop feature + unsigned-dev extensions (needed for Apple Development certs).
defaults write com.apple.Safari IncludeDevelopMenu -bool true
defaults write com.apple.Safari AllowUnsignedExtensions -bool true
SAFARI_PREF="$HOME/Library/Containers/com.apple.Safari/Data/Library/Preferences/com.apple.Safari"
defaults write "$SAFARI_PREF" IncludeDevelopMenu -bool true
defaults write "$SAFARI_PREF" AllowUnsignedExtensions -bool true

open "$INSTALLED"
sleep 1
open -a Safari
say "Agare is installed at ${INSTALLED}. In Safari → Settings → Extensions, turn on Agare. You should not need to hunt for Developer settings — the helper already enabled them."
