#!/usr/bin/env bash
# Renames the template's placeholder game "Game" in a new repository: the
# project name, user folder, export files, bundle identifier and the AGENTS.md
# title. The export files and user folder take the name without spaces or
# symbols, such as OrbitRings for "Orbit Rings". Ends by listing the
# TODO(template) hits that are left.
#
#   tools/init.sh "<Game Name>" [<bundle id>]
set -euo pipefail
cd "$(dirname "$0")/.."
fail() { echo "init: $*" >&2; exit 1; }

[ $# -ge 1 ] && [ $# -le 2 ] || { sed -n '8p' "$0" | sed 's/^# *//'; exit 2; }
name=$1
file=${name//[^A-Za-z0-9]/}
bundle=${2:-dev.evalfoo.$(echo "$file" | tr '[:upper:]' '[:lower:]')}
[ -n "$file" ] || fail "the name needs at least one letter or digit"
case $name in *[\"\\$'\n']*) fail "the name can't hold a quote, backslash or line break" ;; esac
[[ $bundle =~ ^[A-Za-z][A-Za-z0-9-]*(\.[A-Za-z][A-Za-z0-9-]*)+$ ]] || fail "not a bundle id: $bundle"
grep -q '^config/name="Game"$' project.godot || fail "project.godot isn't named Game; already renamed?"

# Escapes a sed replacement that uses | as its delimiter.
esc() { printf '%s' "$1" | sed 's/[\\&|]/\\&/g'; }
n=$(esc "$name")

sed -i.bak -e "s|^config/name=\"Game\"$|config/name=\"$n\"|" \
  -e "s|^config/custom_user_dir_name=\"Game\"$|config/custom_user_dir_name=\"$file\"|" project.godot
sed -i.bak -E -e "s#build/(windows|linux|macos)/Game\.#build/\1/$file.#g" \
  -e "s#com\.example\.game\"#$bundle\"#" export_presets.cfg
sed -i.bak -E -e "s#build/(windows|linux|macos)/Game\.#build/\1/$file.#g" \
  -e '/^# TODO\(template\): rename Game/d' mise.toml
sed -i.bak "s|build/linux/Game\.x86_64|build/linux/$file.x86_64|" .github/workflows/ci.yml
sed -i.bak -e "s|\"~/.local/share/Game\"|\"~/.local/share/$file\"|" \
  -e '/^# TODO(template): match config\/custom_user_dir_name/d' .codex/config.toml
sed -i.bak "1s|^# TODO(template): Game name|# $n|" AGENTS.md
rm -f project.godot.bak export_presets.cfg.bak mise.toml.bak .github/workflows/ci.yml.bak \
  .codex/config.toml.bak AGENTS.md.bak

echo "init: renamed to \"$name\" (files: $file, bundle id: $bundle). TODO(template) hits left:"
git grep -n 'TODO(template)' || true
