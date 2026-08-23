# Registers wallpaper.ps1 to run twice daily. Run once, no admin rights needed.

$Script = Join-Path "$env:USERPROFILE\Pictures\DailyWall" "wallpaper.ps1"
if (-not (Test-Path $Script)) { throw "Put wallpaper.ps1 at $Script first." }

$Action = New-ScheduledTaskAction -Execute "powershell.exe" `
  -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$Script`""
$Triggers = @(
  (New-ScheduledTaskTrigger -Daily -At 9am),
  (New-ScheduledTaskTrigger -Daily -At 12pm)
)
# StartWhenAvailable catches machines that were asleep at the trigger time.
$Settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries `
  -DontStopIfGoingOnBatteries

Register-ScheduledTask -TaskName "DailyWallpaper" -Action $Action -Trigger $Triggers `
  -Settings $Settings -Description "Downloads and sets the daily AI wallpaper." -Force

Start-ScheduledTask -TaskName "DailyWallpaper"
