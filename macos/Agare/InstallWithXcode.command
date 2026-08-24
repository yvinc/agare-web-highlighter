#!/bin/zsh
# Runs in Terminal (outside the app sandbox). Called from Agare’s “Set up with Xcode” button.
set -euo pipefail
export PATH="/usr/bin:/bin:/usr/sbin:/sbin"

APP="$(cd "$(dirname "$0")/../.." && pwd)"
KIT="$APP/Contents/Resources/Kit"
DEST="$HOME/Agare-build"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

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

confirm "Agare will copy an Xcode project to ${DEST} and open it.\\n\\nIn Xcode, choose your Team (your Apple ID) under Signing.\\n\\nContinue?" "Copy project"

rm -rf "$DEST"
ditto "$KIT" "$DEST"

PROJ="$DEST/macos/Agare.xcodeproj"
if [[ ! -d "$PROJ" ]]; then
  if xcrun --find safari-web-extension-converter >/dev/null 2>&1; then
    xcrun safari-web-extension-converter "$DEST" \
      --macos-only --no-prompt --force --no-open \
      --bundle-identifier ca.agare.highlighter \
      --app-name Agare \
      --copy-resources \
      --project-location "$DEST/macos"
  else
    say "The Xcode project is missing and Apple’s Safari packager is not on this Mac."
    exit 1
  fi
fi

open "$PROJ"

CHOICE="$(osascript -e 'button returned of (display dialog "The project is open in Xcode.\n\nSelect the Agare target → Signing & Capabilities → Team → your Apple ID.\n\nBuild now, or press Run in Xcode yourself?" buttons {"I’ll press Run", "Build now"} default button 1 with title "Agare")')" || exit 0

if [[ "$CHOICE" != "Build now" ]]; then
  exit 0
fi

cd "$DEST/macos"
set +e
xcodebuild -project Agare.xcodeproj -scheme Agare -configuration Release \
  -derivedDataPath "$DEST/DerivedData" \
  CODE_SIGN_STYLE=Automatic \
  -allowProvisioningUpdates
STATUS=$?
set -e

if [[ $STATUS -ne 0 ]]; then
  say "Automatic build failed. In Xcode pick your Team under Signing & Capabilities, then press Run."
  exit 1
fi

BUILT="$DEST/DerivedData/Build/Products/Release/Agare.app"
test -d "$BUILT"
test -d "$BUILT/Contents/PlugIns/AgareExtension.appex"

# One Agare.app only — Safari ignores a new build if an old copy is still registered.
killall Agare 2>/dev/null || true
sleep 0.4
rm -rf "$HOME/Applications/Agare.app"
mkdir -p "$HOME/Applications"
ditto "$BUILT" "$HOME/Applications/Agare.app"
if [[ -w /Applications ]]; then
  rm -rf /Applications/Agare.app
  ditto "$BUILT" /Applications/Agare.app
fi

APPEX="$HOME/Applications/Agare.app/Contents/PlugIns/AgareExtension.appex"
"$LSREGISTER" -f "$HOME/Applications/Agare.app" >/dev/null 2>&1 || true
pluginkit -a "$APPEX" >/dev/null 2>&1 || true

open "$HOME/Applications/Agare.app"
say "Build succeeded. Agare is in ~/Applications (the Applications folder in your home directory). Quit Safari fully, tick Allow unsigned extensions, then Extensions → Agare."
