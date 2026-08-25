# Registers wallpaper.ps1 to poll for new releases through the day. Run once,
# no admin rights needed.

$Script = Join-Path "$env:USERPROFILE\WallpaperJourney" "wallpaper.ps1"
if (-not (Test-Path $Script)) { throw "Put wallpaper.ps1 at $Script first." }

$Action = New-ScheduledTaskAction -Execute "powershell.exe" `
  -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$Script`""

# Several polls a day, so a release published after the usual window still
# arrives the same day. A poll with nothing new downloads no image. Logon
# covers machines that were switched off for every scheduled time.
$Triggers = @(4, 8, 12, 16, 20 | ForEach-Object {
  New-ScheduledTaskTrigger -Daily -At ([datetime]::Today.AddHours($_))
})
$Triggers += New-ScheduledTaskTrigger -AtLogOn

# StartWhenAvailable runs a poll that was missed while the machine was asleep.
$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries `
  -DontStopIfGoingOnBatteries -StartWhenAvailable

# Drop the task registered under the old name, or upgrades would leave two
# copies polling.
Unregister-ScheduledTask -TaskName "DailyWallpaper" -Confirm:$false -ErrorAction SilentlyContinue

Register-ScheduledTask -TaskName "WallpaperJourney" -Action $Action -Trigger $Triggers `
  -Settings $Settings -Description "Downloads and sets the daily AI wallpaper." -Force

Start-ScheduledTask -TaskName "WallpaperJourney"
