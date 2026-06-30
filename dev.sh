#!/usr/bin/env bash
set -euo pipefail
# Stop any running installed copy so the dev binary owns the menubar slot.
pkill -f "HappyPRs.app" 2>/dev/null || true
pkill -x "HappyPRs" 2>/dev/null || true

swift run HappyPRs
