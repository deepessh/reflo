#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

DESTINATION="${DESTINATION:-platform=iOS Simulator,name=iPhone 16,OS=18.4}"

xcodegen generate
xcodebuild \
  -scheme Reflo \
  -destination "$DESTINATION" \
  build test
