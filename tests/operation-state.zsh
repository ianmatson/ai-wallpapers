#!/bin/zsh

set -eu

ROOT="${0:A:h:h}"
TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/wallpaper-journey-state-test.XXXXXX")"
TEST_HOME="$TEMP_ROOT/home"
FUNCTIONS="$TEMP_ROOT/wallpaper-functions.zsh"

trap 'rm -rf -- "$TEMP_ROOT"' EXIT

mkdir -p "$TEST_HOME"

# Load the production functions without running its command dispatcher.
awk '/^case "\$\{1:-refresh\}" in$/ { exit } { print }' \
  "$ROOT/consumer/wallpaper.sh" > "$FUNCTIONS"

HOME="$TEST_HOME" zsh -eu -c '
  source "$1"

  # An upgrade gets one cutoff marker, but a no-op apply does not advance it.
  record_apply_success 0
  [[ -e "$APPLIED_MARKER" ]]
  touch -t 202001010000 "$APPLIED_MARKER"
  old_stamp=$(stat -f %m "$APPLIED_MARKER")
  record_apply_success 0
  [[ "$(stat -f %m "$APPLIED_MARKER")" == "$old_stamp" ]]
  record_apply_success 1
  (( $(stat -f %m "$APPLIED_MARKER") > old_stamp ))

  # Completing one operation removes only the event markers that it captured.
  # A marker written while it runs must remain for the next queued apply.
  : > "$SYSTEM_EVENT_MARKER.first"
  capture_system_events
  : > "$SYSTEM_EVENT_MARKER.second"
  complete_system_events
  [[ ! -e "$SYSTEM_EVENT_MARKER.first" ]]
  [[ -e "$SYSTEM_EVENT_MARKER.second" ]]

  # Never reload a partially converged store. Keep the owed marker so a later
  # event can reload after every display has a usable model.
  reload_count=0
  sleep() { :; }
  note() { :; }
  reload_all_spaces() {
    (( reload_count += 1 ))
    rm -f -- "$RELOAD_OWED_MARKER"
  }
  converge_store() { CONVERGE_PENDING=1; }
  : > "$RELOAD_OWED_MARKER"
  settle_and_converge wall-test
  (( reload_count == 0 ))
  [[ -e "$RELOAD_OWED_MARKER" ]]

  # When the next convergence resolves, consume the saved reload request.
  converge_calls=0
  converge_store() {
    (( converge_calls += 1 ))
    (( converge_calls == 1 )) && CONVERGE_PENDING=1 || CONVERGE_PENDING=0
  }
  settle_and_converge wall-test
  (( reload_count == 1 ))
  [[ ! -e "$RELOAD_OWED_MARKER" ]]
' zsh "$FUNCTIONS"

print -- "PASS: reload and apply markers preserve pending state"
