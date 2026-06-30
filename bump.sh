#!/usr/bin/env bash
# Bump the version tag and push it; the release workflow takes it from there.
# Usage: ./bump.sh {major|minor|patch}
set -euo pipefail

PART="${1:-}"
case "$PART" in
  major|minor|patch) ;;
  *) echo "Usage: $0 {major|minor|patch}" >&2; exit 2 ;;
esac

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$REPO_ROOT"

if [ -n "$(git status --porcelain)" ]; then
  echo "Working tree is dirty; commit or stash before bumping." >&2
  exit 1
fi

# Latest v* tag (defaults to v0.0.0 if there isn't one yet).
latest="$(git tag --list 'v*' --sort=-v:refname | head -n1)"
latest="${latest:-v0.0.0}"

if [[ ! "$latest" =~ ^v([0-9]+)\.([0-9]+)\.([0-9]+) ]]; then
  echo "Cannot parse latest tag '$latest' as vMAJOR.MINOR.PATCH" >&2
  exit 1
fi
major="${BASH_REMATCH[1]}"
minor="${BASH_REMATCH[2]}"
patch="${BASH_REMATCH[3]}"

case "$PART" in
  major) major=$((major + 1)); minor=0; patch=0 ;;
  minor) minor=$((minor + 1)); patch=0 ;;
  patch) patch=$((patch + 1)) ;;
esac

new="v${major}.${minor}.${patch}"

if git rev-parse "$new" >/dev/null 2>&1; then
  echo "Tag $new already exists locally." >&2
  exit 1
fi

echo "==> Tagging $new (was $latest)"
git tag "$new"
echo "==> Pushing $new"
git push origin "$new"

echo
echo "Done. Watch the release workflow:"
echo "  https://github.com/frodi-karlsson/happy-prs/actions"
