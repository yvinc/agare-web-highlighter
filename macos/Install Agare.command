#!/bin/zsh
# Double-click in Finder. Builds Agare.app if Xcode is present.
set -euo pipefail
cd "$(dirname "$0")"
ROOT="$(cd .. && pwd)"
APP_OUT="$HOME/Applications/Agare.app"

echo "Agare — 召し上がれ"
echo

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "No Xcode on this Mac. That is fine."
  echo
  echo "Safari 26 can load Agare without Xcode, as a temporary extension:"
  echo "  1. Safari → Settings → Advanced → Show features for web developers"
  echo "  2. Settings → Developer → Allow unsigned extensions"
  echo "  3. Developer → Add Temporary Extension…"
  echo "  4. Choose this folder:"
  echo "     $ROOT"
  echo
  echo "Apple removes temporary extensions when you quit Safari (or after 24 hours)."
  echo "For a lasting install, install Xcode (free) and run this script again."
  open "$ROOT"
  open -a Safari
  read -k1 "?Press any key to close…"
  exit 0
fi

echo "Building Agare.app with the included Xcode project…"
DERIVED="$(pwd)/DerivedData"
rm -rf "$DERIVED"
xcodebuild \
  -project Agare.xcodeproj \
  -scheme Agare \
  -configuration Release \
  -derivedDataPath "$DERIVED" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  ENABLE_HARDENED_RUNTIME=NO \
  | tee /tmp/agare-build.log | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED" || true

BUILT="$DERIVED/Build/Products/Release/Agare.app"
if [[ ! -d "$BUILT" ]]; then
  echo
  echo "Automatic signing needed a personal team. Opening the project in Xcode."
  echo "Select your Apple ID team in Signing, then press Run."
  open Agare.xcodeproj
  exit 1
fi

mkdir -p "$HOME/Applications"
rm -rf "$APP_OUT"
cp -R "$BUILT" "$APP_OUT"
xattr -dr com.apple.quarantine "$APP_OUT" 2>/dev/null || true
open "$APP_OUT"
echo
echo "Agare.app is in ~/Applications. Enable it:"
echo "  Safari → Settings → Developer → Allow unsigned extensions"
echo "  Safari → Settings → Extensions → Agare"
echo
read -k1 "?Press any key to close…"
