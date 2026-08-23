#!/bin/zsh
# Daily wallpaper subscriber for macOS. Assigns one image per monitor, left to
# right as arranged in System Settings > Displays. No permission prompts needed.

REPO="https://github.com/ianmatson/ai-wallpapers"
DIR="$HOME/DailyWall"   # where images are saved — change this and the plist path together
KEEP=7                  # days of wallpapers to retain

mkdir -p "$DIR"

# Resolve today's release tag from the /latest redirect (no API, no token).
TAG=$(curl -fsSL -o /dev/null -w '%{url_effective}' "$REPO/releases/latest") || exit 0
TAG="${TAG##*/}"
[[ "$TAG" == wall-* ]] || exit 0

# One image slot per connected display: 1 monitor gets middle, 2 get the
# adjacent left+middle pair, 3 get all three, more than 3 cycle again.
COUNT=$(osascript -l JavaScript -e 'ObjC.import("AppKit"); $.NSScreen.screens.count' 2>/dev/null)
(( COUNT >= 1 )) || COUNT=1
case $COUNT in
  1) SLOTS=(middle) ;;
  2) SLOTS=(left middle) ;;   # adjacent panels, so the pair stays continuous
  *) ROT=(left middle right)
     SLOTS=()
     for ((i = 0; i < COUNT; i++)); do SLOTS+=("${ROT[$((i % 3 + 1))]}"); done ;;
esac

FILES=()
for SLOT in "${SLOTS[@]}"; do FILES+=("$DIR/$TAG-landscape-$SLOT.jpg"); done

# Download whichever of today's images we don't have yet. New file paths each
# day: macOS often won't repaint if the path is unchanged.
NEW=0
for SLOT in "${(u)SLOTS[@]}"; do
  OUT="$DIR/$TAG-landscape-$SLOT.jpg"
  [[ -s "$OUT" ]] && continue
  curl -fsSL -o "$OUT" "$REPO/releases/latest/download/landscape-$SLOT.jpg" || { rm -f "$OUT"; exit 1; }
  [[ -s "$OUT" ]] || { rm -f "$OUT"; exit 1; }
  NEW=1
done
(( NEW )) || exit 0   # nothing new — don't flash the desktop on a re-run

# Set one image per screen, leftmost first. Keeps each screen's scaling mode.
osascript -l JavaScript - "${FILES[@]}" <<'EOF'
function run(argv) {
  ObjC.import("AppKit");
  const ws = $.NSWorkspace.sharedWorkspace;
  const screens = $.NSScreen.screens.js
    .sort((a, b) => a.frame.origin.x - b.frame.origin.x);
  screens.forEach((s, i) => {
    const url = $.NSURL.fileURLWithPath(argv[i % argv.length]);
    ws.setDesktopImageURLForScreenOptionsError(url, s, ws.desktopImageOptionsForScreen(s), $());
  });
}
EOF

# Keep the newest KEEP days of images.
print -rl -- "$DIR"/wall-*.jpg(N) \
  | sed -E 's|.*/(wall-[0-9]{4}-[0-9]{2}-[0-9]{2}).*|\1|' \
  | sort -ru | tail -n "+$((KEEP + 1))" | while read -r OLD; do
      rm -f "$DIR/$OLD"-*.jpg
    done
