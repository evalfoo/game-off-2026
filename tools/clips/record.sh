#!/usr/bin/env bash
# Records a clip scenario on two git refs and turns the frames into PR clips.
#
#   tools/clips/record.sh <scenario.gd> [<before-ref>] [<after-ref>] [--out <dir>] [--keep-frames] [-- <scenario args>]
#
# With no refs it records origin/main and HEAD. With one ref it records only
# that one, as "after". Each ref is checked out into a throwaway worktree under
# /tmp, which is removed again even when recording fails. Uncommitted game
# changes are not recorded. Linux only. See "Recording clips" in the README.
set -euo pipefail

usage() {
  sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'
  exit 2
}

FPS=30
RESOLUTION=1440x900
GIF_LIMIT=$((8 * 1024 * 1024))

command_line="tools/clips/record.sh $*"
scenario=""
refs=()
out=""
keep_frames=0
scenario_args=()
while [ $# -gt 0 ]; do
  case "$1" in
    --out) out="${2:?--out needs a folder}"; shift 2 ;;
    --keep-frames) keep_frames=1; shift ;;
    --) shift; scenario_args=("$@"); break ;;
    -h|--help) usage ;;
    -*) echo "Unknown option: $1" >&2; usage ;;
    *) if [ -z "$scenario" ]; then scenario="$1"; else refs+=("$1"); fi; shift ;;
  esac
done
[ -n "$scenario" ] || usage
[ -f "$scenario" ] || { echo "No scenario at $scenario" >&2; exit 1; }
[ ${#refs[@]} -le 2 ] || usage
[ ${#refs[@]} -gt 0 ] || refs=(origin/main HEAD)

fail() { echo "$*" >&2; exit 1; }
[ "${BASH_VERSINFO[0]}" -ge 4 ] || fail "Bash 4 or newer is needed."
command -v xvfb-run >/dev/null || fail "xvfb-run is missing. It comes with Xvfb (the xvfb package on Debian and Ubuntu)."
timeout --foreground 1 true 2>/dev/null || fail "GNU timeout is missing. It comes with coreutils."
command -v ffmpeg >/dev/null || fail "ffmpeg is missing. Install it and put it on PATH."
ffmpeg -hide_banner -filters 2>/dev/null | grep ' drawtext ' >/dev/null || fail "ffmpeg has no drawtext filter. Use a build with libfreetype."
command -v godot >/dev/null || fail "godot is missing. Run 'mise install' or put Godot 4.7 on PATH."
font=/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf
[ -f "$font" ] || font=$(fc-match -f '%{file}' sans 2>/dev/null || true)
[ -f "$font" ] || fail "No font for captions. Install DejaVu Sans or fontconfig."

repo=$(git rev-parse --show-toplevel)
# Each ref's import starts from the main checkout's cache, when it has one.
main=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
for ref in "${refs[@]}"; do
  git rev-parse --verify --quiet "$ref^{commit}" >/dev/null || fail "Unknown git ref: $ref"
done
tools_dir=$(cd "$(dirname "$0")" && pwd)
scenario=$(cd "$(dirname "$scenario")" && pwd)/$(basename "$scenario")
name=$(basename "$scenario" .gd)
# Each run claims a new output folder with mkdir, which fails if it exists, so
# two runs never share one. The default name takes the next free suffix.
if [ -z "$out" ]; then
  base=$repo/tests/output/clips/$name-$(date +%F)
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
  echo "Warning: uncommitted changes are not recorded; HEAD is." >&2
fi

# Everything this script may delete, all created by this run: worktree folders
# (removed with git, or with rmdir if git never registered them), scratch
# folders for frames and saves, and the output folder if it is still empty.
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

# Runs Godot for at most <seconds> with the worktree's mise environment.
# --foreground lets Ctrl-C reach Godot, so the cleanup trap runs. Only "native"
# runs get their own Xvfb display, from this repo's tools/native.sh inside mise,
# which sets DISPLAY; the headless import doesn't use the display.
godot_in() {
  local seconds=$1 wt=$2 display=$3; shift 3
  local run=(timeout --foreground "$seconds" godot)
  if [ "$display" = native ]; then
    run=("$tools_dir/../native.sh" "${run[@]}")
  fi
  if command -v mise >/dev/null; then
    run=(mise exec -C "$wt" -- "${run[@]}")
  fi
  "${run[@]}" "$@"
}

frame_file() {
  printf '%s/frames%08d.png' "$frames" "$1"
}

# Field of the first log line starting with a key, e.g. "STRIP 60 3 note".
log_field() {
  awk -v key="$2" -v n="$3" '$1 == key { print $n; exit }' "$1"
}

captions=()
readme_refs=""
readme_commands=""
readme_marks=""
fixture=""
for i in "${!refs[@]}"; do
  ref=${refs[$i]}
  label=${labels[$i]}
  commit=$(git rev-parse --short "$ref^{commit}")
  wt=$(mktemp -d /tmp/clip-wt-XXXXXX)
  wt_dirs+=("$wt")
  frames=$(mktemp -d /tmp/clip-frames-XXXXXX)
  scratch+=("$frames")
  # Saves live here instead of user://, so the trap removes them on every exit.
  saves=$(mktemp -d /tmp/clip-saves-XXXXXX)
  scratch+=("$saves")
  log=$frames/godot.log

  echo "== $label: $ref ($commit) in $wt"
  git -C "$repo" worktree add --quiet --detach "$wt" "$commit"
  worktrees+=("$wt")
  [ -f "$repo/mise.local.toml" ] && cp "$repo/mise.local.toml" "$wt/"
  # The scenario and its base run from this repo, even if the ref predates them.
  mkdir -p "$wt/tools/clips/scenarios"
  cp "$tools_dir/scenario.gd" "$wt/tools/clips/scenario.gd"
  cp "$scenario" "$wt/tools/clips/scenarios/$name.gd"

  echo "   importing"
  "$tools_dir/../seed_import.sh" "$main" "$wt"
  godot_in 1800 "$wt" headless --headless --editor --path "$wt" --import >"$frames/import.log" 2>&1 \
    || { tail -20 "$frames/import.log" >&2; fail "Import failed for $ref"; }

  echo "   recording"
  record=(--path "$wt" --write-movie "$frames/frames.png" --fixed-fps "$FPS" --resolution "$RESOLUTION"
    --script "res://tools/clips/scenarios/$name.gd" -- "--saves=$saves" "${scenario_args[@]}")
  status=0
  godot_in 600 "$wt" native "${record[@]}" >"$log" 2>&1 || status=$?
  count=$(find "$frames" -name 'frames*.png' | wc -l)
  if [ "$status" -ne 0 ] || [ "$count" -eq 0 ]; then
    tail -30 "$log" >&2
    fail "Recording $ref failed (exit $status, $count frames)."
  fi
  grep -E '^(CLIP_START|STRIP|MARK|FIXTURE) ' "$log" | sed 's/^/   /' || true

  start=$(log_field "$log" CLIP_START 2); start=${start:-0}
  last=$((count - 1))
  strip_from=$(log_field "$log" STRIP 2)
  step=$(log_field "$log" STRIP 3)
  note=$(awk '$1 == "STRIP" { $1 = $2 = $3 = ""; sub(/^ +/, ""); print; exit }' "$log")
  [ -f "$(frame_file "$last")" ] || fail "Frames are not numbered 0..$last in $frames."
  [ "$start" -le "$last" ] || fail "CLIP_START is frame $start, but the recording ends at frame $last."
  if [ -z "$strip_from" ]; then
    strip_from=$start
    step=$(( (last - start) / 7 ))
    [ "$step" -gt 0 ] || fail "The clip has $((last - start + 1)) frames; the strip needs 8."
  fi
  [ "$step" -gt 0 ] || fail "strip() step must be 1 or more."
  strip_end=$((strip_from + 7 * step))
  [ "$strip_from" -ge 0 ] && [ "$strip_end" -le "$last" ] \
    || fail "The strip needs frames $strip_from..$strip_end, but the recording ends at frame $last. Call strip() earlier or hold longer after it."
  [ -n "$fixture" ] || fixture=$(sed -n 's/^FIXTURE //p' "$log" | head -1)

  echo "   converting frames $start..$last"
  ffmpeg -v error -y -framerate "$FPS" -start_number "$start" -i "$frames/frames%08d.png" \
    -c:v libx264 -preset slow -crf 20 -pix_fmt yuv420p -movflags +faststart "$out/$label.mp4"
  # Caption text goes through a file so ref names and notes need no escaping.
  printf '%s (%s)   t = %%{eif:(n*%d+%d)*1000/%d:d} ms%s' "$label" "$ref" "$step" "$((strip_from - start))" "$FPS" \
    "${note:+   ($note)}" >"$frames/strip.txt"
  ffmpeg -v error -y -framerate "$FPS" -start_number "$strip_from" -i "$frames/frames%08d.png" \
    -vf "select='not(mod(n\,$step))',trim=end_frame=8,scale=720:-1,pad=iw:ih+34:0:0:white,drawtext=fontfile=$font:textfile=$frames/strip.txt:x=10:y=h-28:fontsize=20:fontcolor=black,tile=2x4:padding=4:color=white" \
    -frames:v 1 -update 1 "$out/$label-strip.png"
  printf '%s (%s)' "${label^}" "$ref" >"$frames/caption.txt"
  captions+=("$frames/caption.txt")

  readme_refs+="- ${label^}: \`$ref\` at $commit ($(git log -1 --format=%s "$commit"))"$'\n'
  # The same for every ref.
  readme_commands="tools/seed_import.sh <main checkout> <worktree>"$'\n'
  readme_commands+="godot --headless --editor --path <worktree> --import"$'\n'
  readme_commands+="tools/native.sh godot ${record[*]//$wt/<worktree>}"$'\n'
  readme_commands=${readme_commands//$frames/<frames>}
  readme_commands=${readme_commands//$saves/<saves>}
  readme_marks+="${label^}:"$'\n'
  while read -r _ at event; do
    readme_marks+="- $(( (at - start) * 1000 / FPS )) ms: $event"$'\n'
  done < <(grep '^MARK ' "$log")
  readme_marks+=$'\n'

  if [ "$keep_frames" -eq 1 ]; then
    mkdir "$out/$label-frames" || fail "$out/$label-frames already exists."
    cp -r "$frames"/. "$out/$label-frames"/
  fi
done

if [ ${#refs[@]} -eq 2 ]; then
  echo "== side by side"
  ffmpeg -v error -y -i "$out/before.mp4" -i "$out/after.mp4" -filter_complex \
    "[0]scale=960:-2,drawtext=fontfile=$font:textfile=${captions[0]}:x=12:y=12:fontsize=26:fontcolor=white:box=1:boxcolor=black@0.7:boxborderw=8[a];\
     [1]scale=960:-2,drawtext=fontfile=$font:textfile=${captions[1]}:x=12:y=12:fontsize=26:fontcolor=white:box=1:boxcolor=black@0.7:boxborderw=8[b];\
     [a][b]hstack" -c:v libx264 -preset slow -crf 22 -pix_fmt yuv420p -movflags +faststart "$out/before-after.mp4"
fi

echo "== gif"
ffmpeg -v error -y -i "$out/after.mp4" -filter_complex \
  "fps=15,scale=800:-1:flags=lanczos,split[s0][s1];[s0]palettegen=stats_mode=diff[p];[s1][p]paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle" \
  "$out/after.gif"
gif_size=$(wc -c <"$out/after.gif")
if [ "$gif_size" -gt "$GIF_LIMIT" ]; then
  echo "Warning: after.gif is $((gif_size / 1024 / 1024)) MB, over 8 MB. Shorten the scenario or attach the MP4." >&2
fi

cat >"$out/README.md" <<EOF
# Clips: $name

Recorded $(date '+%F %H:%M') with Godot Movie Maker at $FPS fps and $RESOLUTION, frame by frame, so runs are deterministic.

- Scenario: \`${scenario#"$repo"/}\`
$readme_refs
Fixture: ${fixture:-not described by the scenario}.

## Timeline

Times are from the start of the clip.

$readme_marks## Files

$(cd "$out" && ls -1 ./*.mp4 ./*.gif ./*.png | sed 's|^\./|- |')

## Commands

\`\`\`sh
$command_line
\`\`\`

Each ref was recorded in a throwaway worktree with:

\`\`\`sh
$readme_commands\`\`\`
EOF

echo "== done: $out"
ls -la "$out"
