#!/usr/bin/env bash
# Installs the Godot version mise.toml pins. When mise can't fetch it, as in a cloud
# agent session whose network blocks mise's release lookups, it downloads the
# release zip from GitHub and registers it with `mise link`, so the mise tasks
# and tools/game_mcp.py run as usual.
#
#   tools/setup.sh
set -euo pipefail
cd "$(dirname "$0")/.."
fail() { echo "setup: $*" >&2; exit 1; }

if ! command -v mise >/dev/null; then
  # Claude Code on the web sets CLAUDE_CODE_REMOTE. Its network blocks the
  # mise.run installer, but not npm. Elsewhere, install mise yourself.
  [ "${CLAUDE_CODE_REMOTE:-}" = true ] || fail "mise is missing; see the README's Setup."
  npm install -g @jdxcode/mise
fi
mise trust -q
mise install godot && exit 0

version=$(sed -n 's/^godot *= *"\(.*\)"$/\1/p' mise.toml)
[ -n "$version" ] || fail "no godot version in mise.toml"
case "$(uname -s)-$(uname -m)" in
  Linux-x86_64) name=Godot_v${version}_linux.x86_64 ;;
  Linux-aarch64) name=Godot_v${version}_linux.arm64 ;;
  *) fail "mise install failed, and the download fallback covers only Linux" ;;
esac
echo "setup: mise install failed; using $name from GitHub" >&2

dir=${XDG_CACHE_HOME:-$HOME/.cache}/godot-releases/$version
if [ ! -x "$dir/godot" ]; then
  mkdir -p "$dir"
  curl -fsSL --retry 3 -o "$dir/$name.zip" \
    "https://github.com/godotengine/godot/releases/download/$version/$name.zip"
  python3 -m zipfile -e "$dir/$name.zip" "$dir"
  rm "$dir/$name.zip"
  chmod +x "$dir/$name"
  ln -sf "$name" "$dir/godot"
fi
mise link -f "godot@$version" "$dir"
