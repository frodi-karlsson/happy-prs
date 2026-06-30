#!/usr/bin/env bash
# Point this clone's git at the tracked .githooks/ directory so hooks
# travel with the repo. Run once after cloning.
set -euo pipefail
git config core.hooksPath .githooks
echo "Git hooks active from .githooks/ (core.hooksPath set)."
