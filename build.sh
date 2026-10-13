#!/bin/bash
set -euo pipefail
BARFOLD_ROOT="$(cd "$(dirname "$0")" && pwd)"
BARFOLD_SDK="$(xcrun --sdk macosx --show-sdk-path)"
BARFOLD_ARCH="$(uname -m)"
BARFOLD_APP="$BARFOLD_ROOT/dist/BarFold.app"
mkdir -p "$BARFOLD_ROOT/.build/module-cache" "$BARFOLD_APP/Contents/MacOS" "$BARFOLD_APP/Contents/Resources"
swiftc -swift-version 6 -O -sdk "$BARFOLD_SDK" -target "$BARFOLD_ARCH-apple-macosx14.0" \
  -module-cache-path "$BARFOLD_ROOT/.build/module-cache" \
  -framework AppKit -framework SwiftUI -framework Carbon -framework ServiceManagement \
  "$BARFOLD_ROOT"/Sources/*.swift -o "$BARFOLD_APP/Contents/MacOS/BarFold"
swiftc -module-cache-path "$BARFOLD_ROOT/.build/module-cache" \
  "$BARFOLD_ROOT/scripts/make-icon.swift" -o "$BARFOLD_ROOT/.build/make-icon"
"$BARFOLD_ROOT/.build/make-icon" "$BARFOLD_ROOT/.build/BarFold.iconset" "$BARFOLD_APP/Contents/Resources/BarFold.icns"
cp "$BARFOLD_ROOT/Resources/Info.plist" "$BARFOLD_APP/Contents/Info.plist"
plutil -lint "$BARFOLD_APP/Contents/Info.plist"
codesign --force --sign - --options runtime "$BARFOLD_APP"
codesign --verify --deep --strict "$BARFOLD_APP"
printf 'Built: %s\n' "$BARFOLD_APP"
