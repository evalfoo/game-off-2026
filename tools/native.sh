#!/bin/sh
# Runs a native command, such as godot --path ., on its own Xvfb display on
# Linux, so native runs in other worktrees don't share its mouse pointer. Godot
# still renders on the GPU there. Run it inside the mise environment, around
# godot itself: mise sets DISPLAY to the shared :1 from mise.local.toml, which
# would override the Xvfb display. Elsewhere it runs the command as it is.
#
#   tools/native.sh godot --path . --script tests/<name>.gd
[ "$(uname)" = Linux ] || exec "$@"
exec xvfb-run -a -s "-screen 0 1920x1080x24" "$@"
