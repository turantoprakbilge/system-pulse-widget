# System Pulse Widget

A lightweight, modern, real-time hardware and system monitor designed for Windows 10/11 taskbars.

![System Pulse](https://img.shields.io/badge/Windows-10%20%2F%2011-blue?style=flat-square)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=flat-square)
![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)

---

## ⚡ Features & Live Metrics

- **SYS / UPTIME:** System uptime (`2d 4h`), and real-time **Top Process** consuming the most CPU (e.g. `chrome (14%)`)
- **CPU:** Real-time utilization (`%`), clock frequency (`GHz`), and package temperature (`C`, Honor BIOS / ACPI)
- **RAM:** Memory load (`%`) and used / total physical memory (`GB`)
- **GPU:** GPU core utilization (`%`) and dedicated/shared memory usage (`GB`)
- **DISK:** Disk active time (`%`), real-time **Read Speed (R)** and **Write Speed (W)**
- **NET:** Real-time **Download Speed (DL)**, **Upload Speed (UL)**, and live **Ping Latency** (`ms`)
- **POWER / BATTERY:** Live **Charge / Discharge Power (Watts)**, battery percentage, **Estimated Remaining Time** (e.g. `3h 45m`), and battery temperature
- **Taskbar Integration:** Docks smoothly right above the taskbar, fully draggable, and automatically remembers its position
- **Context Menu:** Right-click to dock (Bottom Right, Bottom Center, Bottom Left), toggle *Always on Top*, and toggle *Start with Windows*

---

## 🚀 Installation

Run the installation script in PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1
```

This will:
1. Copy the application to `%LOCALAPPDATA%\SystemPulseWidget`.
2. Create shortcuts on your Desktop and Start Menu.
3. Register System Pulse to start with Windows.
4. Launch the application silently in the background.

---

## 🛠️ Manual Launch

Double-click `Start-SystemPulse.cmd`, or run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File .\SystemPulseTaskbar.ps1
```

---

## 🗑️ Uninstallation

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Uninstall.ps1
```

---

## 📄 License

MIT
