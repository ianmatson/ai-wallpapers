#!/bin/zsh

set -eu

ROOT="${0:A:h:h}"
TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/wallpaper-journey-event-test.XXXXXX")"
TEST_HOME="$TEMP_ROOT/home"
FUNCTIONS="$TEMP_ROOT/wallpaper-functions.zsh"

trap 'rm -rf -- "$TEMP_ROOT"' EXIT

mkdir -p "$TEST_HOME"

# Load the production functions without running its command dispatcher.
awk '/^case "\$\{1:-refresh\}" in$/ { exit } { print }' \
  "$ROOT/consumer/wallpaper.sh" > "$FUNCTIONS"

HOME="$TEST_HOME" zsh -eu -c '
  source "$1"

  : > "$APPLIED_MARKER"
  : > "$SYSTEM_EVENT_MARKER.test"
  wallpaper_status() {
    print -r -- "theirs $(( $(date +%s) + 10 ))"
  }

  [[ "$(subscription_sample)" == unknown ]]

  touch -t 202001010000 "$SYSTEM_EVENT_MARKER.test"
  [[ "$(subscription_sample)" == optout ]]
' zsh "$FUNCTIONS"

print -- "PASS: a recent system event suppresses transient opt-out detection"
