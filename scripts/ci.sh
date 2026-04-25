#!/usr/bin/env bash
# Phase 0 CI: build the SwiftPM package, run tests, build the macOS app.
# Mirrors what every commit on this repo should pass.

set -euo pipefail

cd "$(dirname "$0")/.."

echo "==> swift build"
swift build

echo "==> swift test"
swift test

echo "==> xcodebuild -scheme Pavement build"
xcodebuild \
  -project Pavement.xcodeproj \
  -scheme Pavement \
  -configuration Debug \
  -destination 'platform=macOS' \
  build \
  | tail -20

echo "==> ci.sh ok"
