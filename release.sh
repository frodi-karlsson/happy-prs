#!/usr/bin/env bash
# Produce a Cask-ready release artifact: a signed .app bundle inside a
# .tar.gz. Prints the SHA256 needed for the Homebrew cask formula.
#
# Usage: ./release.sh [version]   (default: 0.1.0)
set -euo pipefail

VERSION="${1:-0.1.0}"
APP_NAME="HappyPRs"
DISPLAY_NAME="Happy PRs"
BUNDLE_ID="com.frodikarlsson.happyprs"

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$REPO_ROOT"

OUTPUT_DIR="$REPO_ROOT/release"
APP_STAGING="$OUTPUT_DIR/${DISPLAY_NAME}.app"
TARBALL="$OUTPUT_DIR/happy-prs-${VERSION}.tar.gz"

echo "==> Building release binary"
swift build -c release

echo "==> Bundling into $APP_STAGING"
mkdir -p "$OUTPUT_DIR"
rm -rf "$APP_STAGING"
mkdir -p "$APP_STAGING/Contents/MacOS"
mkdir -p "$APP_STAGING/Contents/Resources"
cp ".build/release/HappyPRsApp" "$APP_STAGING/Contents/MacOS/$APP_NAME"
cp "Resources/Info.plist.template" "$APP_STAGING/Contents/Info.plist"
# Stamp the version into Info.plist's CFBundleShortVersionString.
sed -i.bak "s|<key>CFBundleShortVersionString</key> <string>0.1.0</string>|<key>CFBundleShortVersionString</key> <string>${VERSION}</string>|" "$APP_STAGING/Contents/Info.plist"
rm -f "$APP_STAGING/Contents/Info.plist.bak"

echo "==> Ad-hoc signing as $BUNDLE_ID"
codesign --force --sign - --identifier "$BUNDLE_ID" "$APP_STAGING"

echo "==> Creating tarball"
rm -f "$TARBALL"
tar -czf "$TARBALL" -C "$OUTPUT_DIR" "${DISPLAY_NAME}.app"

SHA256=$(shasum -a 256 "$TARBALL" | awk '{print $1}')

cat <<EOF

==> Done
Tarball: $TARBALL
SHA256:  $SHA256

Next steps:
  1. Cut the GitHub release:
       gh release create v${VERSION} \\
         --title "v${VERSION}" \\
         --notes "see README" \\
         "$TARBALL"
  2. In homebrew-tap, update Casks/happy-prs.rb:
       version "${VERSION}"
       sha256  "${SHA256}"
  3. Commit and push the tap.
EOF
