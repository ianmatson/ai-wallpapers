#!/bin/zsh
# Daily wallpaper subscriber for macOS. The default action downloads the latest
# triptych and applies it. --apply only reapplies the newest cached triptych, so
# the display watcher never needs network access. --check uninstalls everything
# if the user has set their own wallpaper, and --uninstall does so on demand.

set -u

REPO="https://github.com/ianmatson/wallpaper-journey"
DIR="$HOME/DailyWall"   # where images are saved — change this and both plist paths together
KEEP=7                  # days of wallpapers to retain
CURRENT_TAG_FILE="$DIR/current-tag"
APPLIED_MARKER="$DIR/.applied"
LAUNCH_AGENTS="$HOME/Library/LaunchAgents"
DAILY_JOB="com.ianmatson.wallpaper"
WATCHER_JOB="com.ianmatson.wallpaper-watcher"

mkdir -p "$DIR"

cached_tag() {
  local tag=""
  local slot
  local middle

  if [[ -r "$CURRENT_TAG_FILE" ]]; then
    tag="$(<"$CURRENT_TAG_FILE")"
  fi

  # Let existing subscribers upgrade without waiting for the next daily run.
  if [[ "$tag" != wall-[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] ]]; then
    middle=$(print -rl -- "$DIR"/wall-[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-landscape-middle.jpg(N) \
      | sort -r | head -n 1)
    [[ -n "$middle" ]] || return 1
    tag="${middle:t}"
    tag="${tag%-landscape-middle.jpg}"
  fi

  for slot in left middle right; do
    [[ -s "$DIR/$tag-landscape-$slot.jpg" ]] || return 1
  done

  print -r -- "$tag"
}

apply_tag() {
  local tag="$1"
  local count
  local slot
  local i
  local -a slots
  local -a rotation
  local -a files

  # One image slot per connected display: 1 monitor gets middle, 2 get the
  # adjacent left+middle pair, 3 get all three, more than 3 cycle again.
  count=$(osascript -l JavaScript -e 'ObjC.import("AppKit"); $.NSScreen.screens.count' 2>/dev/null)
  (( count >= 1 )) || count=1
  case $count in
    1) slots=(middle) ;;
    2) slots=(left middle) ;;   # adjacent panels, so the pair stays continuous
    *) rotation=(left middle right)
       slots=()
       for ((i = 0; i < count; i++)); do
         slots+=("${rotation[$((i % 3 + 1))]}")
       done ;;
  esac

  files=()
  for slot in "${slots[@]}"; do
    [[ -s "$DIR/$tag-landscape-$slot.jpg" ]] || return 1
    files+=("$DIR/$tag-landscape-$slot.jpg")
  done

  # Set one image per screen, leftmost first. Keeps each screen's scaling mode.
  osascript -l JavaScript - "${files[@]}" <<'EOF'
function run(argv) {
  ObjC.import("AppKit");
  const ws = $.NSWorkspace.sharedWorkspace;
  const screens = $.NSScreen.screens.js.sort((a, b) => {
    const horizontal = a.frame.origin.x - b.frame.origin.x;
    return horizontal || b.frame.origin.y - a.frame.origin.y;
  });
  screens.forEach((screen, index) => {
    const url = $.NSURL.fileURLWithPath(argv[index % argv.length]);
    ws.setDesktopImageURLForScreenOptionsError(
      url,
      screen,
      ws.desktopImageOptionsForScreen(screen),
      $()
    );
  });
}
EOF
  # The marker records that this machine has shown a DailyWall wallpaper, so
  # a pre-install desktop never reads as the user opting back out.
  [[ $? -eq 0 ]] && : > "$APPLIED_MARKER"
}

# Prints "ours" when every screen's wallpaper lives in $DIR, "theirs" when any
# screen shows something else, nothing when the answer is unknowable.
wallpaper_state() {
  osascript -l JavaScript - "$DIR" 2>/dev/null <<'EOF'
function run(argv) {
  ObjC.import("AppKit");
  const dir = argv[0].replace(/\/*$/, "/");
  const ws = $.NSWorkspace.sharedWorkspace;
  const screens = $.NSScreen.screens.js;
  if (screens.length === 0) return "";
  for (const screen of screens) {
    const url = ws.desktopImageURLForScreen(screen);
    // No answer means unknown, not an opt-out: the wallpaper agent reports
    // nothing while it is busy, and guessing there would uninstall us.
    if (url.isNil()) return "";
    const path = ObjC.unwrap(url.path);
    if (!path) return "";
    if (!path.startsWith(dir)) return "theirs";
  }
  return "ours";
}
EOF
}

manual_change() {
  [[ -e "$APPLIED_MARKER" ]] || return 1
  [[ "$(wallpaper_state)" == theirs ]] || return 1
  # Confirm after a pause so our own apply, caught mid-flight with only some
  # screens set, never reads as a manual change.
  sleep 3
  [[ "$(wallpaper_state)" == theirs ]]
}

# Removes everything the installer created. $1 is the launchd job the caller
# runs under; it is booted out last because bootout kills the job's processes,
# which would end this script before the cleanup finished.
uninstall() {
  local last="$1"
  local domain="gui/$(id -u)"
  local job

  for job in "$DAILY_JOB" "$WATCHER_JOB"; do
    [[ "$job" == "$last" ]] && continue
    launchctl bootout "$domain/$job" 2>/dev/null || true
  done

  # Delete only files DailyWall created, in case DIR points at a shared folder.
  rm -f -- \
    "$LAUNCH_AGENTS/$DAILY_JOB.plist" \
    "$LAUNCH_AGENTS/$WATCHER_JOB.plist" \
    /tmp/wallpaper.log /tmp/wallpaper-watcher.log \
    "$DIR"/wall-*(N) "$CURRENT_TAG_FILE" "$APPLIED_MARKER" \
    "$DIR/wallpaper-watcher.js" "$DIR/wallpaper.sh"
  rmdir -- "$DIR" 2>/dev/null || true

  launchctl bootout "$domain/$last" 2>/dev/null || true
}

self_destruct() {
  osascript -e 'display notification "You set your own wallpaper, so DailyWall uninstalled itself and removed its files." with title "DailyWall"' 2>/dev/null || true
  uninstall "$1"
}

prune_cache() {
  print -rl -- "$DIR"/wall-*.jpg(N) \
    | sed -E 's|.*/(wall-[0-9]{4}-[0-9]{2}-[0-9]{2}).*|\1|' \
    | sort -ru | tail -n "+$((KEEP + 1))" | while read -r old; do
        rm -f "$DIR/$old"-*.jpg
      done
}

refresh() {
  local tag
  local slot
  local out
  local tmp
  local tag_tmp

  # Resolve today's release tag from the /latest redirect (no API, no token).
  tag=$(curl -fsSL -o /dev/null -w '%{url_effective}' "$REPO/releases/latest") || return 0
  tag="${tag##*/}"
  [[ "$tag" == wall-* ]] || return 0

  # This runs several times a day so a late release still lands the same day.
  # Once the newest triptych is cached and on screen there is nothing to do,
  # and stopping here avoids re-setting a wallpaper that is already correct.
  if [[ -r "$CURRENT_TAG_FILE" && "$(<"$CURRENT_TAG_FILE")" == "$tag" ]] \
    && [[ "$(wallpaper_state)" == ours ]]; then
    return 0
  fi

  # Cache the complete triptych. Display changes can then choose any layout
  # without downloading another asset.
  for slot in left middle right; do
    out="$DIR/$tag-landscape-$slot.jpg"
    [[ -s "$out" ]] && continue
    tmp="$out.download.$$"
    curl -fsSL -o "$tmp" "$REPO/releases/latest/download/landscape-$slot.jpg" \
      || { rm -f "$tmp"; return 1; }
    [[ -s "$tmp" ]] || { rm -f "$tmp"; return 1; }
    mv "$tmp" "$out"
  done

  # Publish the cache pointer only after all three panels are available.
  tag_tmp="$CURRENT_TAG_FILE.$$"
  print -r -- "$tag" > "$tag_tmp"
  mv "$tag_tmp" "$CURRENT_TAG_FILE"

  apply_tag "$tag" || return 1
  prune_cache
}

case "${1:-refresh}" in
  refresh|--refresh)
    if manual_change; then
      self_destruct "$DAILY_JOB"
    else
      refresh
    fi
    ;;
  apply|--apply)
    tag=$(cached_tag) || exit 0
    apply_tag "$tag"
    ;;
  check|--check)
    if manual_change; then
      self_destruct "$WATCHER_JOB"
    fi
    ;;
  uninstall|--uninstall)
    print -r -- "Removing DailyWall's launch agents, scripts, images, and logs."
    uninstall "$WATCHER_JOB"
    ;;
  *)
    print -u2 -- "usage: $0 [--refresh|--apply|--check|--uninstall]"
    exit 2
    ;;
esac
