# System Pulse Uninstallation Script
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "System Pulse kaldiriliyor..." -ForegroundColor Yellow

# 1. Kill any running System Pulse processes
Get-Process powershell* -ErrorAction SilentlyContinue | Where-Object {
    $_.CommandLine -match 'SystemPulse'
} | Stop-Process -Force -ErrorAction SilentlyContinue

# 2. Remove registry startup key
Remove-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'SystemPulseWidget' -ErrorAction SilentlyContinue
Remove-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'SystemPulseCardWidget' -ErrorAction SilentlyContinue

# 3. Remove Desktop & Start Menu Shortcuts
$desktopDir = [Environment]::GetFolderPath([Environment+SpecialFolder]::Desktop)
if (-not $desktopDir) { $desktopDir = Join-Path $env:USERPROFILE 'Desktop' }
$desktopLnk = Join-Path $desktopDir 'System Pulse.lnk'
if (Test-Path $desktopLnk) { Remove-Item -Path $desktopLnk -Force -ErrorAction SilentlyContinue }

$startMenuDir = [Environment]::GetFolderPath([Environment+SpecialFolder]::Programs)
if (-not $startMenuDir) { $startMenuDir = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs' }
$startMenuLnk = Join-Path $startMenuDir 'System Pulse.lnk'
if (Test-Path $startMenuLnk) { Remove-Item -Path $startMenuLnk -Force -ErrorAction SilentlyContinue }

# 4. Remove AppData directory
$installDir = Join-Path $env:LOCALAPPDATA 'SystemPulseWidget'
if (Test-Path $installDir) { Remove-Item -Path $installDir -Recurse -Force -ErrorAction SilentlyContinue }

Write-Host "[OK] System Pulse basariyla kaldirildi." -ForegroundColor Green
