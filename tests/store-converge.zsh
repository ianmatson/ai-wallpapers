#!/bin/zsh

set -eu

ROOT="${0:A:h:h}"
FIXTURE="$ROOT/tests/store-converge-fixture.jxa"
TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/wallpaper-journey-store-test.XXXXXX")"
STORE="$TEMP_ROOT/Index.plist"
QUERY="$TEMP_ROOT/store-query.jxa"
OWNED="$TEMP_ROOT/WallpaperJourney"
STABLE_PREFIX="$OWNED/current"

trap 'rm -rf -- "$TEMP_ROOT"' EXIT

mkdir -p "$OWNED"

# Run the exact JXA program embedded in wallpaper.sh. This keeps the fixture
# test coupled to production code without a second implementation to maintain.
awk '
  /^store_query\(\) \{/ { in_store_query = 1 }
  in_store_query && /osascript -l JavaScript/ && /EOF/ { capture = 1; next }
  capture && /^EOF$/ { exit }
  capture { print }
' "$ROOT/consumer/wallpaper.sh" > "$QUERY"

[[ -s "$QUERY" ]] || {
  print -u2 -- "FAIL: could not extract store_query from consumer/wallpaper.sh"
  exit 1
}

osascript -l JavaScript "$FIXTURE" write "$STORE" "$STABLE_PREFIX" >/dev/null

first=$(osascript -l JavaScript "$QUERY" \
  converge "$STORE" "$OWNED" "$TEMP_ROOT/Legacy" "$STABLE_PREFIX")
[[ "$first" == *changed* ]] || {
  print -u2 -- "FAIL: the first convergence did not change the fixture"
  exit 1
}

state=$(osascript -l JavaScript "$FIXTURE" inspect "$STORE")
[[ "$state" == *"display-left=$STABLE_PREFIX-left.jpg"* ]] || {
  print -u2 -- "FAIL: the left display did not receive the left panel"
  print -u2 -- "$state"
  exit 1
}
[[ "$state" == *"display-right=$STABLE_PREFIX-right.jpg"* ]] || {
  print -u2 -- "FAIL: the right display did not receive the right panel"
  print -u2 -- "$state"
  exit 1
}
[[ "$state" == *"default-only=$STABLE_PREFIX-left.jpg"* ]] || {
  print -u2 -- "FAIL: the Default-only Space did not move to the active path"
  print -u2 -- "$state"
  exit 1
}

before=$(shasum -a 256 "$STORE" | awk '{ print $1 }')
second=$(osascript -l JavaScript "$QUERY" \
  converge "$STORE" "$OWNED" "$TEMP_ROOT/Legacy" "$STABLE_PREFIX")
after=$(shasum -a 256 "$STORE" | awk '{ print $1 }')

[[ -z "$second" ]] || {
  print -u2 -- "FAIL: the second convergence reported a change: $second"
  exit 1
}
[[ "$before" == "$after" ]] || {
  print -u2 -- "FAIL: the second convergence rewrote the store"
  exit 1
}

missing=$(osascript -l JavaScript "$QUERY" \
  converge "$TEMP_ROOT/missing.plist" "$OWNED" "$TEMP_ROOT/Legacy" "$STABLE_PREFIX")
[[ "$missing" == pending ]] || {
  print -u2 -- "FAIL: an unreadable store did not postpone the reload: $missing"
  exit 1
}

print -- "PASS: shared Space Default convergence is stable after one pass"
