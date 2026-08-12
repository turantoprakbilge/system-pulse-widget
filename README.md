# System Pulse Widget

A lightweight, installation-free Windows 10/11 system monitor. It runs as a clean two-row strip directly above the taskbar.

## Metrics

- CPU package temperature through Honor BIOS-WMI
- CPU utilization and current frequency
- GPU utilization and shared GPU memory
- RAM utilization and used/total memory
- Disk activity and transfer rate
- Network throughput
- Live battery charge or discharge power

All metrics refresh every two seconds. Refreshing pauses while the panel is being dragged to keep movement smooth.

## Run

Double-click `Start-SystemPulse.cmd`, or run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\SystemPulseTaskbar.ps1
```

## Hardware compatibility

CPU temperature is read from `BiosWmi::GetCpuTemp()` in HONOR BasicService on the Honor MagicBook Pro 14. It may be unavailable on other computers. All other metrics use standard Windows performance counters.

## License

MIT
