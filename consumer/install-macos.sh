#!/bin/zsh
# Installs or updates the Wallpaper Journey macOS subscriber. No admin rights
# needed.

set -eu

readonly BASE="https://raw.githubusercontent.com/ianmatson/wallpaper-journey/main/consumer"
readonly HOME_DIR="$HOME/WallpaperJourney"
readonly LEGACY_DIR="$HOME/DailyWall"
readonly LAUNCH_AGENTS="$HOME/Library/LaunchAgents"
readonly DAILY_JOB="com.ianmatson.wallpaper"
readonly WATCHER_JOB="com.ianmatson.wallpaper-watcher"
readonly USER_DOMAIN="gui/$(id -u)"

install_tmp=$(mktemp -d "${TMPDIR:-/tmp}/wallpaper-journey-install.XXXXXX")
trap 'rm -R -- "$install_tmp"' EXIT

for file in \
  wallpaper.sh \
  wallpaper-watcher.js \
  com.ianmatson.wallpaper.plist \
  com.ianmatson.wallpaper-watcher.plist; do
  curl -fsSL -o "$install_tmp/$file" "$BASE/$file"
done

sed -i '' "s|__HOME__|$HOME|g" "$install_tmp/com.ianmatson.wallpaper.plist"
sed -i '' "s|__HOME__|$HOME|g" "$install_tmp/com.ianmatson.wallpaper-watcher.plist"
plutil -lint \
  "$install_tmp/com.ianmatson.wallpaper.plist" \
  "$install_tmp/com.ianmatson.wallpaper-watcher.plist" >/dev/null

mkdir -p "$LAUNCH_AGENTS"

# Stop an older installation only after every replacement file is ready.
launchctl bootout "$USER_DOMAIN/$DAILY_JOB" 2>/dev/null || true
launchctl bootout "$USER_DOMAIN/$WATCHER_JOB" 2>/dev/null || true

# This used to live in ~/DailyWall. Carry the images over, and leave a symlink
# where the folder was: each Space records an absolute path to its wallpaper, so
# without it every desktop set up before the rename would go blank.
if [[ -d "$LEGACY_DIR" && ! -L "$LEGACY_DIR" && ! -e "$HOME_DIR" ]]; then
  mv -- "$LEGACY_DIR" "$HOME_DIR"
  ln -s -- "$HOME_DIR" "$LEGACY_DIR"
fi

mkdir -p "$HOME_DIR"
# launchd redirects the jobs' output here but does not create the directory.
mkdir -p "$HOME/Library/Logs/WallpaperJourney"

install -m 755 "$install_tmp/wallpaper.sh" "$HOME_DIR/wallpaper.sh"
install -m 755 "$install_tmp/wallpaper-watcher.js" "$HOME_DIR/wallpaper-watcher.js"
install -m 644 "$install_tmp/com.ianmatson.wallpaper.plist" "$LAUNCH_AGENTS/com.ianmatson.wallpaper.plist"
install -m 644 "$install_tmp/com.ianmatson.wallpaper-watcher.plist" "$LAUNCH_AGENTS/com.ianmatson.wallpaper-watcher.plist"

launchctl bootstrap "$USER_DOMAIN" "$LAUNCH_AGENTS/com.ianmatson.wallpaper.plist"
launchctl bootstrap "$USER_DOMAIN" "$LAUNCH_AGENTS/com.ianmatson.wallpaper-watcher.plist"
launchctl kickstart -k "$USER_DOMAIN/$DAILY_JOB"

print -r -- "Wallpaper Journey is installed. Today's triptych is downloading now."
