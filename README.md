# System Pulse Widget

## macOS edition (v2.0)

`macOS/` contains a native Apple-silicon-optimized menu-bar application for macOS 14+. It does not require administrator rights and features:

- **Customizable Menu Bar Modes:** Choose between `Power (W/A)`, `CPU/RAM`, `CPU/Temp`, `Network (↓/↑)`, or `All-in-One Compact`.
- **Live Sparkline Charts:** Real-time smooth trend graphs for CPU, RAM, GPU, and Network activity.
- **Top Resource Processes:** Live monitoring of top 4 CPU & Memory consumer applications.
- **CPU & GPU Telemetry:** Overall load, clock frequencies, P-Core & E-Core breakdown, and unified SoC temperature.
- **Fan & Cooling Monitor:** Real-time RPM tracking for dual Apple Silicon cooling fans.
- **Battery Diagnostics:** Live wattage (charge/discharge), amperage, estimated remaining time, battery health percentage, cycle count, and temperature.
- **Network & Ping:** Anonymized throughput (↓ / ↑) and live ping latency.
- **Launch at Login:** Built-in auto-start toggle powered by `ServiceManagement`.

Install it as a regular macOS app (appears in Applications and Launchpad):

```zsh
cd macOS
./install-app.sh
```

Or run it from Terminal without installing:

```zsh
cd macOS
./build-and-run.sh
```

Building requires `macmon` (`brew install macmon`). The installer bundles the MIT-licensed helper inside the app, so the installed `.app` has no runtime dependency on Homebrew.


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
