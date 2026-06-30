#!/usr/bin/env bash
set -euo pipefail

APP_NAME="HappyPRs"
DISPLAY_NAME="Happy PRs"
BUNDLE_ID="com.frodikarlsson.happyprs"
APP_DIR="$HOME/Applications/${DISPLAY_NAME}.app"
BINARY_PATH="$APP_DIR/Contents/MacOS/$APP_NAME"
LAUNCH_AGENT_DIR="$HOME/Library/LaunchAgents"
LAUNCH_AGENT="$LAUNCH_AGENT_DIR/$BUNDLE_ID.plist"

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"

echo "==> Building release binary"
cd "$REPO_ROOT"
swift build -c release

echo "==> Bundling into $APP_DIR"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp ".build/release/$APP_NAME" "$BINARY_PATH"
cp "Resources/Info.plist.template" "$APP_DIR/Contents/Info.plist"

echo "==> Writing LaunchAgent at $LAUNCH_AGENT"
mkdir -p "$LAUNCH_AGENT_DIR"
sed "s#__BINARY_PATH__#$BINARY_PATH#" "Resources/LaunchAgent.plist.template" > "$LAUNCH_AGENT"

echo "==> Loading LaunchAgent"
launchctl bootout "gui/$(id -u)" "$LAUNCH_AGENT" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$LAUNCH_AGENT"

echo "==> Launching app"
open "$APP_DIR"

echo
echo "Done. Happy PRs is installed at $APP_DIR and will start on every login."
echo "Re-run ./install.sh after pulling changes to update."
