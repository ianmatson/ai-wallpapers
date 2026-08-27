#!/bin/zsh

set -eu

ROOT="${0:A:h:h}"
TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/wallpaper-journey-banks-test.XXXXXX")"
TEST_HOME="$TEMP_ROOT/home"
FUNCTIONS="$TEMP_ROOT/wallpaper-functions.zsh"

trap 'rm -rf -- "$TEMP_ROOT"' EXIT

mkdir -p "$TEST_HOME"

# Load the production functions without running its command dispatcher.
awk '/^case "\$\{1:-refresh\}" in$/ { exit } { print }' \
  "$ROOT/consumer/wallpaper.sh" > "$FUNCTIONS"

HOME="$TEST_HOME" zsh -eu -c '
  source "$1"

  first="wall-2026-08-26"
  second="wall-2026-08-27"
  for slot in left middle right; do
    print -rn -- "first-$slot" > "$DIR/$first-landscape-$slot.jpg"
    print -rn -- "second-$slot" > "$DIR/$second-landscape-$slot.jpg"
  done

  publish_stable "$first"
  [[ "$(stable_set)" == a ]]
  stable_matches_tag "$first"
  [[ "$(<"$STABLE_PREFIX-a-left.jpg")" == first-left ]]

  publish_stable "$second"
  [[ "$(stable_set)" == b ]]
  stable_matches_tag "$second"
  [[ "$(<"$STABLE_PREFIX-b-left.jpg")" == second-left ]]
  [[ "$(<"$STABLE_PREFIX-a-left.jpg")" == first-left ]]

  publish_stable "$second"
  [[ "$(stable_set)" == b ]]
  (( STABLE_CHANGED == 0 ))
' zsh "$FUNCTIONS"

print -- "PASS: wallpaper path banks alternate and preserve the previous set"
