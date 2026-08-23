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
mkdir -p ~/Documents/DailyWall
curl -fsSL -o ~/Documents/DailyWall/wallpaper.sh "$BASE/wallpaper.sh"
curl -fsSL -o ~/Library/LaunchAgents/com.ianmatson.wallpaper.plist "$BASE/com.ianmatson.wallpaper.plist"
chmod +x ~/Documents/DailyWall/wallpaper.sh

# Edit wallpaper.sh first if you want to change anything (see below).
sed -i '' "s|__HOME__|$HOME|g" ~/Library/LaunchAgents/com.ianmatson.wallpaper.plist
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.ianmatson.wallpaper.plist
```

Runs once a day at 04:00. macOS will ask once for permission to control System
Events — approve it, then run this to set the wallpaper immediately rather than
waiting for tomorrow:

```sh
launchctl kickstart -k gui/$(id -u)/com.ianmatson.wallpaper
```

Uninstall: `launchctl bootout gui/$(id -u)/com.ianmatson.wallpaper`

## Subscribe — Windows

In PowerShell (no admin needed):

```powershell
$Base = "https://raw.githubusercontent.com/ianmatson/ai-wallpapers/main/consumer"
$Dir  = "$env:USERPROFILE\Documents\DailyWall"
New-Item -ItemType Directory -Force -Path $Dir | Out-Null
iwr "$Base/wallpaper.ps1" -OutFile "$Dir\wallpaper.ps1"
iwr "$Base/install.ps1"   -OutFile "$Dir\install.ps1"

# Edit wallpaper.ps1 first if you want to change anything (see below).
powershell -ExecutionPolicy Bypass -File "$Dir\install.ps1"
```

Creates a `DailyWallpaper` scheduled task that runs at 04:00 and sets the
wallpaper once straight away.

Uninstall: `Unregister-ScheduledTask -TaskName DailyWallpaper -Confirm:$false`

## Customising

Both settings live at the top of the script you downloaded —
`wallpaper.sh` on macOS, `wallpaper.ps1` on Windows.

**Which image.** Pick the one that suits your display:

```sh
FILE="landscape-1.jpg"   # or landscape-2.jpg, or portrait-1.jpg
```

**Where images are saved.** Default is `~/Documents/DailyWall`:

```sh
DIR="$HOME/Documents/DailyWall"        # macOS
```
```powershell
$Dir = "$env:USERPROFILE\Documents\DailyWall"   # Windows
```

On macOS the script itself and the images live in the same folder, so if you move
`DIR` you must move `wallpaper.sh` there too and update the matching path in
`~/Library/LaunchAgents/com.ianmatson.wallpaper.plist`. On Windows the script
path is set separately in `install.ps1`, so `$Dir` only affects the images.

## Notes

- macOS keeps the last 7 days of images (change `KEEP=7`); Windows keeps one file.
- Both scripts no-op when there's no new release, so a re-run won't flash your
  desktop.
- macOS only repaints reliably when the file path changes, so each day's image
  gets a date-stamped name.
- If the machine is asleep at 04:00, macOS runs the job at the next wake and
  Windows waits until tomorrow. Either way you just miss a day, which is fine.
- If you sync Desktop & Documents to iCloud, `~/Documents/DailyWall` will sync
  too. Point `DIR` somewhere outside iCloud if you'd rather not upload it.
- Spaces created after the wallpaper is set may not inherit it. If that bugs you,
  `brew install wallpaper` and swap the `osascript` line for
  `wallpaper set "$OUT"`.
- Release asset downloads don't count against GitHub API rate limits.
- Only the newest 30 releases are kept; older days are deleted.
