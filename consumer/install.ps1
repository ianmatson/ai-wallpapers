# Registers wallpaper.ps1 to run daily at 4am. Run once, no admin rights needed.

$Script = Join-Path "$env:USERPROFILE\DailyWall" "wallpaper.ps1"
if (-not (Test-Path $Script)) { throw "Put wallpaper.ps1 at $Script first." }

$Action = New-ScheduledTaskAction -Execute "powershell.exe" `
  -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$Script`""
$Trigger = New-ScheduledTaskTrigger -Daily -At 4am
$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

Register-ScheduledTask -TaskName "DailyWallpaper" -Action $Action -Trigger $Trigger `
  -Settings $Settings -Description "Downloads and sets the daily AI wallpaper." -Force

Start-ScheduledTask -TaskName "DailyWallpaper"
