# ai-wallpapers

Every day codex generates a new wallpaper — follow along here.

A new [release](https://github.com/ianmatson/ai-wallpapers/releases) is published
daily, tagged `wall-YYYY-MM-DD`. The asset names never change, so these URLs
always point at today's images:

| Image | URL |
| --- | --- |
| Landscape 1 | `https://github.com/ianmatson/ai-wallpapers/releases/latest/download/landscape-1.jpg` |
| Landscape 2 | `https://github.com/ianmatson/ai-wallpapers/releases/latest/download/landscape-2.jpg` |
| Portrait 1 | `https://github.com/ianmatson/ai-wallpapers/releases/latest/download/portrait-1.jpg` |

Grab one by hand whenever you like, or subscribe below and your desktop updates
itself every morning. No GitHub account or token needed.

## Subscribe — macOS

```sh
BASE=https://raw.githubusercontent.com/ianmatson/ai-wallpapers/main/consumer
mkdir -p ~/Pictures/DailyWall
curl -fsSL -o ~/Pictures/DailyWall/wallpaper.sh "$BASE/wallpaper.sh"
curl -fsSL -o ~/Library/LaunchAgents/com.ianmatson.wallpaper.plist "$BASE/com.ianmatson.wallpaper.plist"
chmod +x ~/Pictures/DailyWall/wallpaper.sh

# Want portrait, or the second landscape? Edit the FILE= line now.
sed -i '' "s|__HOME__|$HOME|g" ~/Library/LaunchAgents/com.ianmatson.wallpaper.plist
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.ianmatson.wallpaper.plist
```

Runs at login and at 09:00 and 12:00 — the second run covers Macs that were
asleep. macOS will ask once for permission to control System Events; approve it,
then run `launchctl kickstart -k gui/$(id -u)/com.ianmatson.wallpaper` to set the
wallpaper straight away.

Uninstall: `launchctl bootout gui/$(id -u)/com.ianmatson.wallpaper`

## Subscribe — Windows

In PowerShell (no admin needed):

```powershell
$Base = "https://raw.githubusercontent.com/ianmatson/ai-wallpapers/main/consumer"
$Dir  = "$env:USERPROFILE\Pictures\DailyWall"
New-Item -ItemType Directory -Force -Path $Dir | Out-Null
iwr "$Base/wallpaper.ps1" -OutFile "$Dir\wallpaper.ps1"
iwr "$Base/install.ps1"   -OutFile "$Dir\install.ps1"

# Want portrait, or the second landscape? Edit the $File line now.
powershell -ExecutionPolicy Bypass -File "$Dir\install.ps1"
```

Creates a `DailyWallpaper` scheduled task that runs at 09:00 and 12:00 and
catches up after sleep.

Uninstall: `Unregister-ScheduledTask -TaskName DailyWallpaper -Confirm:$false`

## Notes

- Images land in `~/Pictures/DailyWall` (macOS keeps the last 7 days, Windows
  keeps one file).
- Both scripts no-op when the image hasn't changed, so the midday run won't
  flash your desktop.
- macOS only repaints reliably when the file path changes, so each day's image
  gets a date-stamped name.
- Spaces created after the wallpaper is set may not inherit it. If that bugs you,
  `brew install wallpaper` and swap the `osascript` line for
  `wallpaper set "$OUT"`.
- Release asset downloads don't count against GitHub API rate limits.
- Only the newest 30 releases are kept; older days are deleted.
