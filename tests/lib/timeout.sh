#!/usr/bin/env bash
# Runs a command and stops it with TERM after <seconds>, for tests/run.sh where
# neither timeout nor gtimeout is installed, as on a stock Mac.
#
#   tests/lib/timeout.sh <seconds> <command> [<args>...]
#
# Exits with the command's status, 143 when the timer stopped it. The timer
# writes to /dev/null, so it never holds open a pipe the command writes to.
"${@:2}" &
pid=$!
trap 'kill $pid 2>/dev/null' INT TERM
# The timer stops its sleep when it is stopped itself, so no sleep outlives it.
(sleep "$1" & sleeper=$!; trap 'kill $sleeper; exit' TERM; wait $sleeper; kill $pid) >/dev/null 2>&1 &
timer=$!
wait $pid
status=$?
kill $timer 2>/dev/null
exit $status
