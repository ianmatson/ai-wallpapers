#!/bin/zsh
# Daily wallpaper subscriber for macOS. Edit FILE, then schedule with the plist.

REPO="https://github.com/ianmatson/ai-wallpapers"
FILE="landscape-1.jpg"   # landscape-1.jpg | landscape-2.jpg | portrait-1.jpg
DIR="$HOME/Documents/DailyWall"   # where images are saved — change this and the plist path together
KEEP=7                   # days of wallpapers to retain

mkdir -p "$DIR"

# Resolve today's release tag from the /latest redirect (no API, no token).
TAG=$(curl -fsSL -o /dev/null -w '%{url_effective}' "$REPO/releases/latest") || exit 0
TAG="${TAG##*/}"
[[ "$TAG" == wall-* ]] || exit 0

# New path each day: macOS often won't repaint if the file path is unchanged.
OUT="$DIR/$TAG-$FILE"
[[ -f "$OUT" ]] && exit 0

curl -fsSL -o "$OUT" "$REPO/releases/latest/download/$FILE" || { rm -f "$OUT"; exit 1; }
[[ -s "$OUT" ]] || { rm -f "$OUT"; exit 1; }

osascript -e "tell application \"System Events\" to tell every desktop to set picture to \"$OUT\""

ls -t "$DIR"/wall-*-"$FILE" 2>/dev/null | tail -n "+$((KEEP + 1))" | while read -r old; do
  rm -f "$old"
done
