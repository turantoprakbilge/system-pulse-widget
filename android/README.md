# System Pulse for Android

Android companion to the Windows System Pulse widget in this repository. The UI keeps the same dark, compact PULSE identity while using metrics Android makes available to ordinary apps.

## Live metrics

- CPU utilization sampled from `/proc/stat` when exposed by the device
- Average current CPU frequency from sysfs when exposed by the kernel
- RAM used / total and utilization
- Internal data storage used / total
- Combined device network throughput via `TrafficStats`
- Battery level, charging state, battery temperature and instantaneous current-derived power estimate
- Device model and Android version

The dashboard refreshes every two seconds.

## Android limitations

Modern Android intentionally restricts access to several system-wide hardware counters. A normal non-root app cannot reliably obtain universal GPU utilization or SoC/CPU temperature across vendors. The app therefore does not fake these values. CPU frequency may also be hidden by a vendor kernel. Battery temperature and power are exposed where the device reports them.

## Build

1. Open the `android/` directory in Android Studio.
2. Use JDK 17.
3. Let Gradle sync dependencies.
4. Run the `app` configuration on an Android 8.0+ device.

The project targets Android API 36 and uses Jetpack Compose / Material 3.

## Architecture

- `SystemMonitor.kt`: low-level metric collection and rate sampling.
- `MainActivity.kt`: reactive Compose dashboard with a 2-second refresh loop.

No analytics, account, server, background service, or internet permission is required.
