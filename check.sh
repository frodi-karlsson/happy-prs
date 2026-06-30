#!/usr/bin/env bash
# Run all the checks CI runs, in one pass, locally. Convenient before
# pushing — same toolchain, same strictness.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$REPO_ROOT"

echo "==> swift-format lint"
xcrun swift-format lint \
  --recursive --strict \
  --configuration .swift-format \
  Sources Tests

if command -v actionlint >/dev/null 2>&1; then
  echo "==> actionlint"
  actionlint -color
else
  echo "==> actionlint (skipped — not installed)"
  echo "    Install with: brew install actionlint"
fi

echo "==> swift build (debug)"
swift build

echo "==> swift build (release)"
swift build -c release

echo "==> swift test"
swift test

echo
echo "All checks passed."
