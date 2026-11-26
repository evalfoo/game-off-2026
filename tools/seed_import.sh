#!/usr/bin/env bash
# Copies the Godot import cache (.godot/) from another checkout into a new
# worktree, so the import that follows redoes only the assets that differ.
# Godot compares each asset with the md5 it recorded at import time.
#
#   tools/seed_import.sh <from-checkout> <to-worktree>
#
# Does nothing when <from-checkout> has no cache or <to-worktree> already has
# one. On Linux the copy shares blocks where the file system allows it.
set -euo pipefail

[ $# -eq 2 ] || { sed -n '6p' "$0" | sed 's/^# *//' >&2; exit 2; }
from=$1/.godot
to=$2/.godot
[ -d "$from" ] && [ ! -e "$to" ] || exit 0

flags=(-a)
[ "$(uname)" != Linux ] || flags+=(--reflink=auto)
# A failed copy only costs time, so drop it and let the import start cold.
cp "${flags[@]}" "$from" "$to" || { echo "Could not copy $from; importing from nothing." >&2; rm -rf "$to"; }
