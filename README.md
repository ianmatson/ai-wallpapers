# ai-wallpapers

Every day codex generates a new wallpaper — a matching set of three: left,
middle, and right. Follow along here.

A new [release](https://github.com/ianmatson/ai-wallpapers/releases) is published
daily, tagged `wall-YYYY-MM-DD`. The asset names never change, so these URLs
always point at today's images:

| Image | URL |
| --- | --- |
| Left | `https://github.com/ianmatson/ai-wallpapers/releases/latest/download/landscape-left.jpg` |
| Middle | `https://github.com/ianmatson/ai-wallpapers/releases/latest/download/landscape-middle.jpg` |
| Right | `https://github.com/ianmatson/ai-wallpapers/releases/latest/download/landscape-right.jpg` |

Grab one by hand whenever you like, or subscribe below and your device updates
itself every morning. No GitHub account or token needed.

## Subscribe — macOS

```sh
BASE=https://raw.githubusercontent.com/ianmatson/ai-wallpapers/main/consumer
mkdir -p ~/DailyWall
curl -fsSL -o ~/DailyWall/wallpaper.sh "$BASE/wallpaper.sh"
curl -fsSL -o ~/DailyWall/wallpaper-watcher.js "$BASE/wallpaper-watcher.js"
curl -fsSL -o ~/Library/LaunchAgents/com.ianmatson.wallpaper.plist "$BASE/com.ianmatson.wallpaper.plist"
curl -fsSL -o ~/Library/LaunchAgents/com.ianmatson.wallpaper-watcher.plist "$BASE/com.ianmatson.wallpaper-watcher.plist"
chmod +x ~/DailyWall/wallpaper.sh ~/DailyWall/wallpaper-watcher.js

sed -i '' "s|__HOME__|$HOME|g" ~/Library/LaunchAgents/com.ianmatson.wallpaper.plist
sed -i '' "s|__HOME__|$HOME|g" ~/Library/LaunchAgents/com.ianmatson.wallpaper-watcher.plist
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.ianmatson.wallpaper.plist
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.ianmatson.wallpaper-watcher.plist
launchctl kickstart -k gui/$(id -u)/com.ianmatson.wallpaper
```

Downloads all three images once a day at 04:00 and puts one image on each
monitor, matching your left-to-right arrangement in System Settings → Displays:

| Monitors | You get |
| --- | --- |
| 1 | middle |
| 2 | left + middle (adjacent, so the panels flow) |
| 3 | left + middle + right |
| 4+ | left/middle/right, repeating |

No permission prompts. Adding, removing, or rearranging a monitor reapplies the
cached images automatically without another download. To download and set
today's wallpaper immediately instead of waiting for 04:00:

```sh
launchctl kickstart -k gui/$(id -u)/com.ianmatson.wallpaper
```

Uninstall:

```sh
launchctl bootout gui/$(id -u)/com.ianmatson.wallpaper
launchctl bootout gui/$(id -u)/com.ianmatson.wallpaper-watcher
```

## Subscribe — iPhone and iPad

Install the [Daily Background shortcut](https://www.icloud.com/shortcuts/7e6407d39a0f42bf8187600761266203),
then run it once and approve the requested permissions. The shortcut downloads
the latest `landscape-middle.jpg` and applies it to your selected wallpaper.

After installing, you may need to edit the shortcut's **Set Wallpaper Photo**
action and select the wallpaper you want it to change each day.

## Subscribe — Windows

In PowerShell (no admin needed):

```powershell
$Base = "https://raw.githubusercontent.com/ianmatson/ai-wallpapers/main/consumer"
$Dir  = "$env:USERPROFILE\DailyWall"
New-Item -ItemType Directory -Force -Path $Dir | Out-Null
iwr "$Base/wallpaper.ps1" -OutFile "$Dir\wallpaper.ps1"
iwr "$Base/install.ps1"   -OutFile "$Dir\install.ps1"

# Optional: edit the $File line in wallpaper.ps1 to pick left/middle/right.
powershell -ExecutionPolicy Bypass -File "$Dir\install.ps1"
```

Creates a `DailyWallpaper` scheduled task that runs at 04:00 and sets the
wallpaper once straight away. Windows gets a single image on all monitors
(`landscape-middle.jpg` by default).

Uninstall: `Unregister-ScheduledTask -TaskName DailyWallpaper -Confirm:$false`

## Customising

Settings live at the top of the script you downloaded — `wallpaper.sh` on
macOS, `wallpaper.ps1` on Windows.

**Where images are saved.** Default is `~/DailyWall`:

```sh
DIR="$HOME/DailyWall"        # macOS
```
```powershell
$Dir = "$env:USERPROFILE\DailyWall"   # Windows
```

On macOS the scripts and images live in the same folder, so if you move `DIR`
you must move `wallpaper.sh` and `wallpaper-watcher.js` there too and update the
matching paths in both wallpaper plists under `~/Library/LaunchAgents`. On
Windows the script path is set separately in `install.ps1`, so `$Dir` only
affects the images.

**Which image (Windows only).** Edit `$File` in `wallpaper.ps1`. macOS picks
images automatically from your monitor layout.

## Notes

- Portrait monitors get a centre-cropped version of their slot's image
  automatically (macOS "Fill Screen" scaling).
- The iPhone and iPad shortcut updates the wallpaper selected in its **Set
  Wallpaper Photo** action. Select it again if importing the shortcut does not
  preserve that choice.
- macOS keeps the last 7 days of images (change `KEEP=7`); Windows keeps one file.
- The macOS display watcher only reads cached files; monitor changes never make
  network requests.
- New macOS Spaces created after the wallpaper is set may not inherit it —
  known macOS quirk; it corrects itself at the next daily run.
- If the machine is asleep at 04:00, macOS runs the job at the next wake and
  Windows waits until tomorrow. Either way you just miss a day, which is fine.
- Release asset downloads don't count against GitHub API rate limits.
- Only the newest 30 releases are kept; older days are deleted.
