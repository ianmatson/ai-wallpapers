# wallpaper-journey

Every day codex generates a new wallpaper — a matching set of three: left,
middle, and right. Follow along here.

In theory these backgrounds should play out as a story evolving over time, but we'll see about that, won't we?

A new [release](https://github.com/ianmatson/wallpaper-journey/releases) is published
daily at ***roughly*** 3am, tagged `wall-YYYY-MM-DD`. The asset names never change, so these URLs
always point at today's images:

| Image | URL |
| --- | --- |
| Left | `https://github.com/ianmatson/wallpaper-journey/releases/latest/download/landscape-left.jpg` |
| Middle | `https://github.com/ianmatson/wallpaper-journey/releases/latest/download/landscape-middle.jpg` |
| Right | `https://github.com/ianmatson/wallpaper-journey/releases/latest/download/landscape-right.jpg` |

Grab one by hand whenever you like, or subscribe below and your device updates
itself every morning. No GitHub account or token needed.

## Production

The deterministic release work is handled by the versioned
[`producer/pipeline.zsh`](producer/pipeline.zsh) CLI. Codex supplies the visual
direction, image generation and review, story sentence, and playlist judgment;
the script handles validation, upscaling coordination, staging, publishing,
embedded previews, and retention. See [`producer/README.md`](producer/README.md)
for the command contract.

## Subscribe — macOS

```sh
curl -fsSL https://raw.githubusercontent.com/ianmatson/wallpaper-journey/main/consumer/install-macos.sh | zsh
```

That installs or updates Wallpaper Journey without admin rights, downloads
today's triptych, and watches for monitor changes. If you prefer to inspect each
step, the equivalent manual installation is:

<details>
<summary>Manual installation</summary>

```sh
BASE=https://raw.githubusercontent.com/ianmatson/wallpaper-journey/main/consumer
mkdir -p ~/WallpaperJourney
curl -fsSL -o ~/WallpaperJourney/wallpaper.sh "$BASE/wallpaper.sh"
curl -fsSL -o ~/WallpaperJourney/wallpaper-watcher.js "$BASE/wallpaper-watcher.js"
curl -fsSL -o ~/Library/LaunchAgents/com.ianmatson.wallpaper.plist "$BASE/com.ianmatson.wallpaper.plist"
curl -fsSL -o ~/Library/LaunchAgents/com.ianmatson.wallpaper-watcher.plist "$BASE/com.ianmatson.wallpaper-watcher.plist"
chmod +x ~/WallpaperJourney/wallpaper.sh ~/WallpaperJourney/wallpaper-watcher.js

sed -i '' "s|__HOME__|$HOME|g" ~/Library/LaunchAgents/com.ianmatson.wallpaper.plist
sed -i '' "s|__HOME__|$HOME|g" ~/Library/LaunchAgents/com.ianmatson.wallpaper-watcher.plist
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.ianmatson.wallpaper.plist
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.ianmatson.wallpaper-watcher.plist
launchctl kickstart -k gui/$(id -u)/com.ianmatson.wallpaper
```

</details>

Checks for a new release at 04:00, 08:00, 12:00, 16:00, and 20:00 (and at
login), downloads all three images the first time it sees one, and puts one
image on each monitor, matching your left-to-right arrangement in System
Settings → Displays:

| Monitors | You get |
| --- | --- |
| 1 | middle |
| 2 | left + middle (adjacent, so the panels flow) |
| 3 | left + middle + right |
| 4+ | left/middle/right, repeating |

No permission prompts. The desktops (Spaces) on screen change straight away, and
each of your other desktops takes today's image the first time you switch to it
after installing. From then on that desktop is updated by the morning run too,
whether or not you are looking at it. Adding, removing, or rearranging a monitor
reapplies the cached images automatically without another download. Polling several times a day means a release published late — or one
that failed and was retried — still reaches you the same day. To download and
set today's wallpaper immediately instead of waiting for the next poll:

```sh
launchctl kickstart -k gui/$(id -u)/com.ianmatson.wallpaper
```

### Uninstall — macOS

You usually never need to: **just set your own wallpaper** in System Settings.
Wallpaper Journey notices within a few seconds, uninstalls itself completely
(launch agents, scripts, cached images, and logs), and posts a notification
saying so.

To uninstall by hand instead:

```sh
zsh ~/WallpaperJourney/wallpaper.sh --uninstall
```

Both paths remove everything the installer created: the two launch agents and
their plists, `~/WallpaperJourney`, and the logs in `/tmp`.

## Subscribe — iPhone and iPad

Install the [Daily Background shortcut](https://www.icloud.com/shortcuts/7e6407d39a0f42bf8187600761266203),
then run it once and approve the requested permissions. The shortcut downloads
the latest `landscape-middle.jpg` and applies it to your selected wallpaper.

After installing, you may need to edit the shortcut's **Set Wallpaper Photo**
action and select the wallpaper you want it to change each day.

## Subscribe — Windows

In PowerShell (no admin needed):

```powershell
$Base = "https://raw.githubusercontent.com/ianmatson/wallpaper-journey/main/consumer"
$Dir  = "$env:USERPROFILE\WallpaperJourney"
New-Item -ItemType Directory -Force -Path $Dir | Out-Null
iwr "$Base/wallpaper.ps1" -OutFile "$Dir\wallpaper.ps1"
iwr "$Base/install.ps1"   -OutFile "$Dir\install.ps1"

# Optional: edit the $File line in wallpaper.ps1 to pick left/middle/right.
powershell -ExecutionPolicy Bypass -File "$Dir\install.ps1"
```

Creates a `WallpaperJourney` scheduled task that checks for a new release at
04:00, 08:00, 12:00, 16:00, and 20:00 (and at logon), and sets the wallpaper
once straight away. Windows gets a single image on all monitors
(`landscape-middle.jpg` by default).

### Uninstall — Windows

As on macOS, **just set your own wallpaper** — the next poll notices, uninstalls
the task, removes Wallpaper Journey's files, and shows a notification. To
uninstall by hand instead:

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\WallpaperJourney\wallpaper.ps1" -Uninstall
```

## Customising

Settings live at the top of the script you downloaded — `wallpaper.sh` on
macOS, `wallpaper.ps1` on Windows.

**Where images are saved.** Default is `~/WallpaperJourney`:

```sh
DIR="$HOME/WallpaperJourney"        # macOS
```
```powershell
$Dir = "$env:USERPROFILE\WallpaperJourney"   # Windows
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
- A poll that finds nothing new costs one redirect request on either platform
  and exits without downloading an image or touching your wallpaper, so the
  extra polls are close to free. To change the schedule, edit the
  `StartCalendarInterval` entries in
  `~/Library/LaunchAgents/com.ianmatson.wallpaper.plist` on macOS, or the
  trigger hours in `install.ps1` and rerun it on Windows.
- The macOS display watcher only reads cached files; monitor changes never make
  network requests.
- Setting your own wallpaper on **any** screen counts as opting out on macOS —
  Wallpaper Journey uninstalls itself entirely rather than fight you for the
  other screens at the next poll.
- This was called DailyWall until August 2026. Rerunning the macOS installer
  renames `~/DailyWall` to `~/WallpaperJourney` and leaves a symlink behind,
  because each Space records an absolute path to its wallpaper; without it every
  desktop set up before the rename would go blank. Uninstalling removes the
  symlink. On Windows the old `DailyWallpaper` scheduled task is unregistered
  when you rerun `install.ps1`.
- macOS notices an opt-out within seconds, because the watcher listens for the
  system's background-changed notification. Windows has no equivalent resident
  process, so it notices at the next scheduled poll — up to four hours later.
- The opt-out detection compares the current wallpaper path against Wallpaper Journey's
  own file: `~/WallpaperJourney` on macOS, `current.jpg` on Windows. If you keep old
  macOS Spaces that still show a wallpaper from before you subscribed, visiting one can read
  as opting out.
- On macOS every Space stores its wallpaper as a file path, and the only public
  API to set one reaches the Space on screen. So the wallpaper is always the
  same three paths — `current-left.jpg`, `current-middle.jpg`,
  `current-right.jpg` — and the daily run swaps the images behind them and
  restarts the wallpaper agent, which reloads every Space from disk. One
  download in the morning reaches all of them, and a Space made later inherits
  a path that is already current.
- Those fixed paths are hard links to the dated files, so the archive costs no
  extra disk, and pruning a dated name never takes the image away from a Space
  still using it.
- Spaces set up by an earlier version still point at a dated filename. Each one
  moves to the fixed path the first time you visit it after upgrading; until
  then it keeps showing the image it last received.
- If the machine is asleep at a scheduled poll, both platforms run the job at
  the next wake (Windows via the task's `StartWhenAvailable`), and the remaining
  polls that day give it more chances.
- Release asset downloads don't count against GitHub API rate limits.
- Only the newest 30 releases are kept; older days are deleted.
