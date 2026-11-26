#!/usr/bin/env bash
# Prints the next release version without the "v", for example 0.2.0.
# Prints nothing when the newest v* tag already points at HEAD, so the release
# workflow skips weeks without changes. The first release is 0.1.0.
# Usage: tools/next_version.sh minor|patch
set -euo pipefail

bump="${1:?usage: tools/next_version.sh minor|patch}"
last=$(git describe --tags --abbrev=0 --match 'v[0-9]*' 2>/dev/null || true)

if [ -z "$last" ]; then
  echo 0.1.0
  exit 0
fi
if [ "$(git rev-list -n 1 "$last")" = "$(git rev-parse HEAD)" ]; then
  exit 0
fi

IFS=. read -r major minor patch <<< "${last#v}"
case "$bump" in
  minor) echo "$major.$((minor + 1)).0" ;;
  patch) echo "$major.$minor.$((patch + 1))" ;;
  *) echo "unknown bump: $bump" >&2; exit 1 ;;
esac
