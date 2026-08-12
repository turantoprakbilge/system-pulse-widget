@echo off
start "System Pulse" powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0SystemPulse.ps1"
