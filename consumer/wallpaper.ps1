# Daily wallpaper subscriber for Windows. Edit $File, then schedule with install.ps1.

$Repo = "https://github.com/ianmatson/wallpaper-journey"
$File = "landscape-middle.jpg"   # landscape-left.jpg | landscape-middle.jpg | landscape-right.jpg
$Dir  = "$env:USERPROFILE\DailyWall"   # where images are saved

New-Item -ItemType Directory -Force -Path $Dir | Out-Null
$Out = Join-Path $Dir "current.jpg"
$Tmp = Join-Path $Dir "download.tmp"

try {
  Invoke-WebRequest "$Repo/releases/latest/download/$File" -OutFile $Tmp -UseBasicParsing
} catch { exit 1 }

# Skip the repaint if today's image is byte-identical to what is already set.
if ((Test-Path $Out) -and (Get-FileHash $Tmp).Hash -eq (Get-FileHash $Out).Hash) {
  Remove-Item $Tmp -Force
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
