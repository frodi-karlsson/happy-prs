#!/usr/bin/env bash
set -euo pipefail
BUNDLE_ID="com.frodikarlsson.happyprs"
APP_DIR="$HOME/Applications/Happy PRs.app"
LAUNCH_AGENT="$HOME/Library/LaunchAgents/$BUNDLE_ID.plist"

echo "==> Unloading LaunchAgent"
launchctl bootout "gui/$(id -u)" "$LAUNCH_AGENT" 2>/dev/null || true

echo "==> Removing LaunchAgent plist"
rm -f "$LAUNCH_AGENT"

echo "==> Removing app bundle"
rm -rf "$APP_DIR"

echo "==> Stopping running process"
pkill -x "HappyPRs" 2>/dev/null || true

echo
echo "Done. Happy PRs uninstalled. Settings remain in ~/Library/Preferences."
echo "To also clear settings: defaults delete $BUNDLE_ID"
