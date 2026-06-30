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

# Ad-hoc re-sign the bundle so Info.plist is sealed and the codesign
# identifier matches CFBundleIdentifier. Without this, UNUserNotifications
# can't attribute permission to the bundle ID and silently denies.
echo "==> Ad-hoc signing the bundle as $BUNDLE_ID"
codesign --force --sign - --identifier "$BUNDLE_ID" "$APP_DIR"

echo "==> Writing LaunchAgent at $LAUNCH_AGENT"
mkdir -p "$LAUNCH_AGENT_DIR"
sed "s#__BINARY_PATH__#$BINARY_PATH#" "Resources/LaunchAgent.plist.template" > "$LAUNCH_AGENT"

echo "==> Stopping any running instance"
# `launchctl bootout` only kills processes managed by launchd; an instance
# launched via `open` or `swift run` is orphaned and won't be touched.
pkill -x "$APP_NAME" 2>/dev/null || true
launchctl bootout "gui/$(id -u)" "$LAUNCH_AGENT" 2>/dev/null || true

echo "==> Loading LaunchAgent (RunAtLoad starts the app)"
launchctl bootstrap "gui/$(id -u)" "$LAUNCH_AGENT"

echo
echo "Done. Happy PRs is installed at $APP_DIR and will start on every login."
echo "Re-run ./install.sh after pulling changes to update."
