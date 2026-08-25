# Daily wallpaper subscriber for Windows. Edit $File, then schedule with
# install.ps1. The default run polls for a new release and applies it;
# -Uninstall removes the scheduled task and every file DailyWall created.
#
# The task polls several times a day so a release published after the usual
# window still arrives the same day. A poll with nothing new costs one redirect
# request and downloads no image.

param([switch]$Uninstall)

$Repo = "https://github.com/ianmatson/wallpaper-journey"
$File = "landscape-middle.jpg"   # landscape-left.jpg | landscape-middle.jpg | landscape-right.jpg
$Dir  = "$env:USERPROFILE\DailyWall"   # where images are saved
$TaskName = "DailyWallpaper"

$Out     = Join-Path $Dir "current.jpg"
$Tmp     = Join-Path $Dir "download.tmp"
$TagFile = Join-Path $Dir "current-tag"
$Marker  = Join-Path $Dir "applied.txt"

# Resolves the newest release tag from the /latest redirect without downloading
# the page or any asset. Returns $null when the network is unavailable.
function Get-LatestTag {
  $location = $null
  try {
    $request = [System.Net.HttpWebRequest]::Create("$Repo/releases/latest")
    $request.Method = "HEAD"
    $request.AllowAutoRedirect = $false
    $request.UserAgent = "DailyWall"
    $response = $request.GetResponse()
    $location = $response.Headers["Location"]
    $response.Close()
  } catch { return $null }

  if (-not $location) { return $null }
  $tag = $location.TrimEnd('/').Split('/')[-1]
  if ($tag -notlike 'wall-*') { return $null }
  return $tag
}

function Get-DesktopWallpaper {
  try {
    (Get-ItemProperty 'HKCU:\Control Panel\Desktop' -Name WallPaper -ErrorAction Stop).WallPaper
  } catch { return "" }
}

# True once the user has set their own wallpaper, which is treated as opting out.
function Test-ManualChange {
  # Only after we have applied a wallpaper at least once, so a fresh install
  # never reads the pre-existing desktop as an opt-out.
  if (-not (Test-Path $Marker)) { return $false }

  $current = Get-DesktopWallpaper
  if ([string]::IsNullOrEmpty($current)) { return $false }
  if ($current -eq $Out) { return $false }

  # Windows redirects this value to its own transcoded copy in some flows, so
  # require the change to be clearly newer than our last apply rather than
  # trusting the path alone. The margin keeps the transcode that Windows writes
  # during our own apply from reading as a manual change.
  try {
    $changedAt = (Get-Item $current -ErrorAction Stop).LastWriteTime
  } catch { return $false }
  return $changedAt -gt (Get-Item $Marker).LastWriteTime.AddSeconds(60)
}

function Show-Notice($Text) {
  try {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    $notify = New-Object System.Windows.Forms.NotifyIcon
    $notify.Icon = [System.Drawing.SystemIcons]::Information
    $notify.Visible = $true
    $notify.ShowBalloonTip(10000, "DailyWall", $Text, 'Info')
    Start-Sleep -Seconds 10
    $notify.Dispose()
  } catch { }
}

function Invoke-Uninstall {
  # Delete only files DailyWall created, in case $Dir is a shared folder, and
  # do it before unregistering: removing the task can terminate this process.
  foreach ($path in @($Out, $Tmp, $TagFile, $Marker,
                      (Join-Path $Dir "install.ps1"),
                      (Join-Path $Dir "wallpaper.ps1"))) {
    Remove-Item $path -Force -ErrorAction SilentlyContinue
  }
  try {
    if (-not (Get-ChildItem $Dir -Force -ErrorAction Stop)) {
      Remove-Item $Dir -Force -ErrorAction SilentlyContinue
    }
  } catch { }

  Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
}

if ($Uninstall) {
  Write-Host "Removing DailyWall's scheduled task, script, images, and state."
  Invoke-Uninstall
  exit 0
}

New-Item -ItemType Directory -Force -Path $Dir | Out-Null

if (Test-ManualChange) {
  Show-Notice "You set your own wallpaper, so DailyWall uninstalled itself and removed its files."
  Invoke-Uninstall
  exit 0
}

$tag = Get-LatestTag
if (-not $tag) { exit 0 }   # offline or GitHub hiccup; the next poll retries

# Nothing new since the last poll, so skip the download entirely.
if ((Test-Path $TagFile) -and (Test-Path $Out) -and
    ((Get-Content $TagFile -Raw).Trim() -eq $tag)) {
  exit 0
}

try {
  Invoke-WebRequest "$Repo/releases/latest/download/$File" -OutFile $Tmp -UseBasicParsing
} catch { exit 1 }

# Skip the repaint if today's image is byte-identical to what is already set.
if ((Test-Path $Out) -and (Get-FileHash $Tmp).Hash -eq (Get-FileHash $Out).Hash) {
  Remove-Item $Tmp -Force
  Set-Content -Path $TagFile -Value $tag
  exit 0
}
Move-Item $Tmp $Out -Force

# Fill the screen rather than stretch or tile.
Set-ItemProperty 'HKCU:\Control Panel\Desktop' -Name WallpaperStyle -Value 10
Set-ItemProperty 'HKCU:\Control Panel\Desktop' -Name TileWallpaper -Value 0

Add-Type @"
using System.Runtime.InteropServices;
public class Wallpaper {
  [DllImport("user32.dll", CharSet = CharSet.Auto)]
  public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
"@
# SPI_SETDESKWALLPAPER = 20, SPIF_UPDATEINIFILE | SPIF_SENDCHANGE = 3
[Wallpaper]::SystemParametersInfo(20, 0, $Out, 3) | Out-Null

Set-Content -Path $TagFile -Value $tag
# Written last so its timestamp is never earlier than the apply it records.
Set-Content -Path $Marker -Value (Get-Date -Format o)
