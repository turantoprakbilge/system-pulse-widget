# System Pulse Installation Script
$ErrorActionPreference = 'Stop'

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  Installing System Pulse Widget...      " -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

$sourceDir = $PSScriptRoot
if (-not $sourceDir) { $sourceDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $sourceDir) { $sourceDir = "C:\Users\turan\system-pulse-widget" }

$installDir = Join-Path $env:LOCALAPPDATA 'SystemPulseWidget'
if (-not (Test-Path $installDir)) {
    New-Item -ItemType Directory -Path $installDir -Force | Out-Null
}

# Stop old running instances if any
Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match 'SystemPulseTaskbar' } | ForEach-Object {
    Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
}

# Copy files
$filesToCopy = @('SystemPulseTaskbar.ps1', 'SystemPulse.ps1', 'Start-SystemPulse.cmd', 'launcher.vbs', 'README.md', 'LICENSE')
foreach ($f in $filesToCopy) {
    $src = Join-Path $sourceDir $f
    if (Test-Path $src) {
        Copy-Item -Path $src -Destination (Join-Path $installDir $f) -Force
    }
}

# 1. Windows Run Autostart Registry Key
$runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$vbsPath = Join-Path $installDir 'launcher.vbs'
$startCmd = "wscript.exe //B `"$vbsPath`""
Set-ItemProperty -Path $runKey -Name 'SystemPulseWidget' -Value $startCmd
Write-Host "[OK] Added to Windows Startup." -ForegroundColor Green

# 2. Desktop Shortcut
$wsh = New-Object -ComObject WScript.Shell
$desktopDir = [Environment]::GetFolderPath([Environment+SpecialFolder]::Desktop)
if (-not $desktopDir) { $desktopDir = Join-Path $env:USERPROFILE 'Desktop' }
$desktopLnk = Join-Path $desktopDir 'System Pulse.lnk'
$shortcut = $wsh.CreateShortcut($desktopLnk)
$shortcut.TargetPath = "wscript.exe"
$shortcut.Arguments = "//B `"$vbsPath`""
$shortcut.WorkingDirectory = $installDir
$shortcut.Description = "System Pulse - Taskbar Hardware Monitor"
$shortcut.Save()
Write-Host "[OK] Desktop shortcut created: $desktopLnk" -ForegroundColor Green

# 3. Start Menu Shortcut
$startMenuDir = [Environment]::GetFolderPath([Environment+SpecialFolder]::Programs)
if (-not $startMenuDir) { $startMenuDir = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs' }
$startMenuLnk = Join-Path $startMenuDir 'System Pulse.lnk'
$shortcutMenu = $wsh.CreateShortcut($startMenuLnk)
$shortcutMenu.TargetPath = "wscript.exe"
$shortcutMenu.Arguments = "//B `"$vbsPath`""
$shortcutMenu.WorkingDirectory = $installDir
$shortcutMenu.Description = "System Pulse - Taskbar Hardware Monitor"
$shortcutMenu.Save()
Write-Host "[OK] Start Menu shortcut created: $startMenuLnk" -ForegroundColor Green

# 4. Launch System Pulse Taskbar Widget now
Write-Host "[OK] Starting System Pulse..." -ForegroundColor Green
Start-Process -FilePath "wscript.exe" -ArgumentList "//B `"$vbsPath`"" -WorkingDirectory $installDir

Write-Host "=========================================" -ForegroundColor Green
Write-Host "  Installation Complete! System Pulse Active." -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
