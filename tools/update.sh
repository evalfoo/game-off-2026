#!/usr/bin/env bash
# Updates a game made from the template to a tag of the template: copies the
# generic files FILES lists from that tag, stages them, and records the tag in
# tools/template-version. The game's own parts, such as game/play_hooks.gd and
# tools/ui_shots.gd, aren't listed, so it leaves them alone. Fixes to the
# listed files belong in the template.
#
#   tools/update.sh <template tag>
#
# It refuses when a listed file has changes that aren't committed. Listed
# files the game edited get the template's copy; `git diff --staged` shows
# what changed. TEMPLATE_REPO overrides the template's repository.
set -euo pipefail

# The template's generic files. A folder brings all of its files, and loses
# those the tag doesn't have.
FILES=(
  tools/update.sh
  tools/play_driver.gd tools/play_driver.gd.uid
  tools/game_mcp.py
  tools/native.sh
  tools/seed_import.sh
  tools/clips/record.sh tools/clips/stills.sh
  tools/clips/scenario.gd tools/clips/scenario.gd.uid
  tests/run.sh
  tests/lib
  tests/play_events.gd tests/play_events.gd.uid
  tests/replay_native.gd tests/replay_native.gd.uid
)

fail() { echo "update: $*" >&2; exit 1; }

main() {
  [ $# -eq 1 ] || { sed -n '8p' "$0" | sed 's/^# *//' >&2; exit 2; }
  local tag=$1

  # First run: fetch the tag, then run the tag's copy of this script with
  # UPDATE_FROM set to the fetched commit, so its FILES apply, and this file
  # can change under it. Keep this handshake in later versions.
  if [ -z "${UPDATE_FROM:-}" ]; then
    cd "$(dirname "$0")/.."
    local repo=${TEMPLATE_REPO:-git@github.com:evalfoo/godot-template.git}
    git fetch --quiet --no-tags "$repo" "refs/tags/$tag" || fail "can't fetch tag $tag from $repo"
    local script
    script=$(git show FETCH_HEAD:tools/update.sh) || fail "tag $tag has no tools/update.sh"
    UPDATE_FROM=$(git rev-parse 'FETCH_HEAD^{commit}') exec bash -c "$script" tools/update.sh "$tag"
  fi

  if [ -n "$(git status --porcelain -- "${FILES[@]}")" ]; then
    git status --short -- "${FILES[@]}" >&2
    fail "commit or discard the changes to these files first"
  fi
  git restore --source="$UPDATE_FROM" --staged --worktree -- "${FILES[@]}"
  echo "$tag" >tools/template-version
  git add tools/template-version
  git diff --staged --stat
  echo "update: now on template $tag. Review with git diff --staged, run mise run import and the checks, then commit."
}

main "$@"
