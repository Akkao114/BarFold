#!/bin/bash
set -euo pipefail
BARFOLD_ROOT="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$BARFOLD_ROOT/.build/module-cache" "$BARFOLD_ROOT/artifacts"
swiftc -swift-version 6 -module-cache-path "$BARFOLD_ROOT/.build/module-cache" \
  "$BARFOLD_ROOT/Sources/LayoutPolicy.swift" "$BARFOLD_ROOT/Sources/Preferences.swift" \
  "$BARFOLD_ROOT/Tests/CoreTests.swift" -o "$BARFOLD_ROOT/.build/core-tests"
"$BARFOLD_ROOT/.build/core-tests" | tee "$BARFOLD_ROOT/artifacts/core-tests.txt"
