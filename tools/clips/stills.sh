#!/usr/bin/env bash
# Runs a shot script on two git refs and collects its screenshots for a PR.
#
#   tools/clips/stills.sh [<shots.gd>] [<before-ref>] [<after-ref>] [--out <dir>] [-- <script args>]
#
# The shot script defaults to tools/ui_shots.gd. It must save PNGs into the
# folder given as --out=<dir>. With no refs it runs on origin/main and HEAD; with
# one ref, only that one, as "after". Each file <name>.png lands in the output
# folder as before-<name>.png or after-<name>.png. Refs run in throwaway
# worktrees under /tmp, as in record.sh. Linux and macOS. See "Screenshots"
# in the README.
set -euo pipefail

usage() {
  sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'
  exit 2
}

FPS=30
RESOLUTION=1440x900

shots=""
refs=()
out=""
script_args=()
while [ $# -gt 0 ]; do
  case "$1" in
    --out) out="${2:?--out needs a folder}"; shift 2 ;;
    --) shift; script_args=("$@"); break ;;
    -h|--help) usage ;;
    -*) echo "Unknown option: $1" >&2; usage ;;
    *.gd) [ -z "$shots" ] || usage; shots="$1"; shift ;;
    *) refs+=("$1"); shift ;;
  esac
done
repo=$(git rev-parse --show-toplevel)
# Each ref's import starts from the main checkout's cache, when it has one.
main=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
[ -n "$shots" ] || shots=$repo/tools/ui_shots.gd
[ -f "$shots" ] || { echo "No shot script at $shots" >&2; exit 1; }
[ ${#refs[@]} -le 2 ] || usage
[ ${#refs[@]} -gt 0 ] || refs=(origin/main HEAD)

fail() { echo "$*" >&2; exit 1; }
[ "${BASH_VERSINFO[0]}" -ge 4 ] || fail "Bash 4 or newer is needed."
# macOS needs no Xvfb: tools/native.sh opens the window on the desktop there.
[ "$(uname)" != Linux ] || command -v xvfb-run >/dev/null \
  || fail "xvfb-run is missing. It comes with Xvfb (the xvfb package on Debian and Ubuntu)."
if timeout --foreground 1 true 2>/dev/null; then timeout=timeout
elif gtimeout --foreground 1 true 2>/dev/null; then timeout=gtimeout
else fail "GNU timeout is missing. It comes with coreutils (on macOS: brew install coreutils, as gtimeout)."
fi
command -v godot >/dev/null || fail "godot is missing. Run 'mise install' or put Godot 4.7 on PATH."

for ref in "${refs[@]}"; do
  git rev-parse --verify --quiet "$ref^{commit}" >/dev/null || fail "Unknown git ref: $ref"
done
tools_dir=$(cd "$(dirname "$0")" && pwd)
shots=$(cd "$(dirname "$shots")" && pwd)/$(basename "$shots")
name=$(basename "$shots" .gd)
# Like record.sh, each run claims a new output folder.
if [ -z "$out" ]; then
  base=$repo/tests/output/stills/$name-$(date +%F)
  mkdir -p "$(dirname "$base")"
  out=$base; n=1
  until mkdir "$out" 2>/dev/null; do
    [ -e "$out" ] || fail "Cannot create $out"
    n=$((n + 1)); out=$base-$n
  done
else
  mkdir -p "$(dirname "$out")"
  mkdir "$out" 2>/dev/null || fail "Cannot create $out. --out must be a new folder."
fi
out=$(cd "$out" && pwd)

if [ ${#refs[@]} -eq 2 ]; then labels=(before after); else labels=(after); fi
if [[ " ${refs[*]} " == *" HEAD "* ]] && ! git diff --quiet HEAD; then
  echo "Warning: uncommitted changes are not shot; HEAD is." >&2
fi

# Everything this script may delete, all created by this run.
wt_dirs=()
worktrees=()
scratch=()
cleanup() {
  for wt in "${worktrees[@]}"; do
    git -C "$repo" worktree remove --force "$wt" || echo "Could not remove worktree $wt" >&2
  done
  for dir in "${wt_dirs[@]}"; do
    [ ! -d "$dir" ] || rmdir "$dir" || echo "Left $dir behind" >&2
  done
  for dir in "${scratch[@]}"; do
    rm -rf "$dir"
  done
  rmdir "$out" 2>/dev/null || true
}
trap cleanup EXIT
trap 'exit 130' INT TERM

# Only "native" runs get their own Xvfb display, as in record.sh; the headless
# import doesn't use the display.
godot_in() {
  local seconds=$1 wt=$2 display=$3; shift 3
  local run=("$timeout" --foreground "$seconds" godot)
  if [ "$display" = native ]; then
    run=("$tools_dir/../native.sh" "${run[@]}")
  fi
  if command -v mise >/dev/null; then
    run=(mise exec -C "$wt" -- "${run[@]}")
  fi
  "${run[@]}" "$@"
}

for i in "${!refs[@]}"; do
  ref=${refs[$i]}
  label=${labels[$i]}
  commit=$(git rev-parse --short "$ref^{commit}")
  wt=$(mktemp -d /tmp/stills-wt-XXXXXX)
  wt_dirs+=("$wt")
  shot_dir=$(mktemp -d /tmp/stills-shots-XXXXXX)
  scratch+=("$shot_dir")
  saves=$(mktemp -d /tmp/stills-saves-XXXXXX)
  scratch+=("$saves")
  log=$shot_dir/godot.log

  echo "== $label: $ref ($commit) in $wt"
  git -C "$repo" worktree add --quiet --detach "$wt" "$commit"
  worktrees+=("$wt")
  [ -f "$repo/mise.local.toml" ] && cp "$repo/mise.local.toml" "$wt/"
  # The shot script and its base run from this repo on both refs, so both get
  # the same fixture and camera.
  mkdir -p "$wt/tools/clips/stills"
  cp "$tools_dir/scenario.gd" "$wt/tools/clips/scenario.gd"
  cp "$shots" "$wt/tools/clips/stills/$name.gd"

  echo "   importing"
  "$tools_dir/../seed_import.sh" "$main" "$wt"
  godot_in 1800 "$wt" headless --headless --editor --path "$wt" --import >"$shot_dir/import.log" 2>&1 \
    || { tail -20 "$shot_dir/import.log" >&2; fail "Import failed for $ref"; }

  echo "   shooting"
  mkdir "$shot_dir/png"
  status=0
  godot_in 600 "$wt" native --path "$wt" --resolution "$RESOLUTION" --fixed-fps "$FPS" --script "res://tools/clips/stills/$name.gd" \
    -- "--out=$shot_dir/png" "--saves=$saves" "${script_args[@]}" >"$log" 2>&1 || status=$?
  count=$(find "$shot_dir/png" -name '*.png' | wc -l)
  if [ "$status" -ne 0 ] || [ "$count" -eq 0 ]; then
    tail -30 "$log" >&2
    fail "Shooting $ref failed (exit $status, $count screenshots)."
  fi
  for png in "$shot_dir/png"/*.png; do
    cp "$png" "$out/$label-$(basename "$png")"
  done
  echo "   $count screenshots"
done

echo "== done: $out"
ls -1 "$out"
