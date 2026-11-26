#!/usr/bin/env bash
# Runs test scripts and lists the failures at the end.
#
#   tests/run.sh headless      every tests/*.gd except *_native.gd, then a parse check of every script
#   tests/run.sh native        every tests/*_native.gd, each on its own Xvfb display (tools/native.sh),
#                              then the game MCP server's self-test
#   tests/run.sh <script.gd>   one script, native when its name ends in _native.gd
#
# A script fails on a non-zero exit, on a SCRIPT ERROR line in its output
# (Godot often exits 0 after one), or after 5 minutes, timed by timeout, else
# Homebrew's gtimeout on macOS, else tests/lib/timeout.sh. Logs go to
# tests/output/logs/. A new test needs no registration: name it tests/<x>.gd or
# tests/<x>_native.gd. Helpers live in tests/lib/, which isn't run.
set -euo pipefail
cd "$(dirname "$0")/.."
shopt -s nullglob

scripts=()
case "${1:-}" in
  headless) for f in tests/*.gd; do [[ $f == *_native.gd ]] || scripts+=("$f"); done ;;
  native) scripts=(tests/*_native.gd) ;;
  *.gd) scripts=("$1") ;;
  *) sed -n '4,7p' "$0" | sed 's/^# *//'; exit 2 ;;
esac

if command -v timeout >/dev/null; then
  limit=(timeout 300)
elif command -v gtimeout >/dev/null; then
  limit=(gtimeout 300)
else
  echo "[test] timeout and gtimeout are missing (on macOS: brew install coreutils); using tests/lib/timeout.sh"
  limit=(tests/lib/timeout.sh 300)
fi

logs=tests/output/logs
mkdir -p "$logs"
failed=()

for script in "${scripts[@]}"; do
  if [[ $script == *_native.gd ]]; then
    run=(tools/native.sh "${limit[@]}" godot --path . --script "$script")
  else
    run=("${limit[@]}" godot --headless --path . --script "$script")
  fi
  log=$logs/$(basename "$script" .gd).log
  echo "[test] ${run[*]}"
  started=$SECONDS
  status=0
  "${run[@]}" 2>&1 | tee "$log" || status=$?
  if [ "$status" -ne 0 ] || grep -q 'SCRIPT ERROR' "$log"; then
    failed+=("$script (exit $status, $log)")
  fi
  echo "[test] $((SECONDS - started)) s: $script"
done

# Drives a game through the game MCP server. Without the test XDG_DATA_HOME,
# its mise exec finds the shared tools instead of installing them again.
if [ "${1:-}" = native ]; then
  echo "[test] python3 tools/game_mcp.py --self-test"
  started=$SECONDS
  env -u XDG_DATA_HOME python3 tools/game_mcp.py --self-test 2>&1 | tee "$logs/game_mcp.log" \
    || failed+=("tools/game_mcp.py --self-test ($logs/game_mcp.log)")
  echo "[test] $((SECONDS - started)) s: tools/game_mcp.py --self-test"
fi

# Parse-check scripts that the tests may not load.
if [ "${1:-}" = headless ]; then
  # A class_name in a prototype is global, and the parse error blames the
  # game script that reuses the name, so name the prototype file instead.
  if [ -d prototypes ]; then
    for f in $(grep -rlE --include='*.gd' '^class_name[[:space:]]' prototypes); do
      echo "[test] $f declares class_name; prototypes preload their scripts instead"
      failed+=("class_name in a prototype: $f")
    done
  fi
  for f in $(find game tools tests -name '*.gd' | sort); do
    godot --headless --path . --check-only --script "$f" >"$logs/check.log" 2>&1 \
      || { cat "$logs/check.log"; failed+=("parse check: $f"); }
  done
fi

if [ ${#failed[@]} -gt 0 ]; then
  echo "[test] FAILED:"
  printf '  %s\n' "${failed[@]}"
  exit 1
fi
echo "[test] all ${#scripts[@]} scripts passed"
