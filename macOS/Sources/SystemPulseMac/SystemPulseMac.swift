import SwiftUI
import IOKit
import IOKit.ps
import Darwin.Mach
import ServiceManagement
import SystemPulseCore

public enum MenuBarMode: String, CaseIterable, Identifiable {
    case power = "Power"
    case cpuRam = "CPU/RAM"
    case cpuTemp = "CPU/Temp"
    case network = "Network"
    case compact = "Compact"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .power: return "⚡ Power"
        case .cpuRam: return "􀧓 CPU/RAM"
        case .cpuTemp: return "􀇬 CPU/Temp"
        case .network: return "􀤆 Network"
        case .compact: return "🌟 All-in-One"
        }
    }
}

@main
struct SystemPulseMacApp: App {
    @State private var monitor = SystemMonitor()

    var body: some Scene {
        MenuBarExtra {
            PulseMenu(monitor: monitor)
        } label: {
            HStack(spacing: 5) {
                switch monitor.menuBarMode {
                case .power:
                    Image(systemName: "bolt.fill")
                        .foregroundStyle(.orange)
                    Text(monitor.powerWatts)
                    Text(monitor.currentAmps)

                case .cpuRam:
                    Image(systemName: "cpu")
                        .foregroundStyle(.blue)
                    Text("\(monitor.cpuPercent)%")
                    Image(systemName: "memorychip")
                        .foregroundStyle(.green)
                    Text("\(monitor.memoryPercent)%")

                case .cpuTemp:
                    Image(systemName: "cpu")
                        .foregroundStyle(.blue)
                    Text("\(monitor.cpuPercent)%")
                    Image(systemName: "thermometer.medium")
                        .foregroundStyle(monitor.cpuTempColor)
                    Text(monitor.cpuTemperature)

                case .network:
                    Image(systemName: "arrow.down")
                        .foregroundStyle(.pink)
                    Text(monitor.downloadRate.replacingOccurrences(of: "↓ ", with: ""))
                    Image(systemName: "arrow.up")
                        .foregroundStyle(.pink)
                    Text(monitor.uploadRate)

                case .compact:
                    Image(systemName: "bolt.fill")
                        .foregroundStyle(.orange)
                    Text(monitor.powerWatts)
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text("\(monitor.cpuPercent)%")
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text(monitor.cpuTemperature)
                }
            }
            .font(.system(size: 12, weight: .medium))
            .monospacedDigit()
        }
        .menuBarExtraStyle(.window)
    }
}

private struct SparklineView: View {
    let data: [Double]
    let color: Color
    var isPercent: Bool = true

    var body: some View {
        GeometryReader { geo in
            if data.count > 1 {
                let maxVal = isPercent ? 100.0 : max(1.0, data.max() ?? 1.0)
                let minVal = 0.0
                let points = data.indices.map { i -> CGPoint in
                    let x = geo.size.width * CGFloat(i) / CGFloat(data.count - 1)
                    let ratio = CGFloat((data[i] - minVal) / max(1.0, maxVal - minVal))
                    let clampedRatio = min(max(ratio, 0.0), 1.0)
                    let y = geo.size.height * (1.0 - clampedRatio)
                    return CGPoint(x: x, y: y)
                }

                Path { path in
                    path.move(to: points[0])
                    for pt in points.dropFirst() {
                        path.addLine(to: pt)
                    }
                }
                .stroke(color.opacity(0.85), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))

                Path { path in
                    path.move(to: CGPoint(x: points[0].x, y: geo.size.height))
                    path.addLine(to: points[0])
                    for pt in points.dropFirst() {
                        path.addLine(to: pt)
                    }
                    path.addLine(to: CGPoint(x: points.last!.x, y: geo.size.height))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.22), color.opacity(0.01)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
        .frame(height: 18)
    }
}

private struct PulseMenu: View {
    @Bindable var monitor: SystemMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 34, height: 34)
                    .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text("System Pulse")
                        .font(.headline)
                    Text("Mac performance & system monitor")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(monitor.uptime)
                        .foregroundStyle(.secondary)
                        .font(.caption)
                        .monospacedDigit()
                    Toggle("Auto-start", isOn: $monitor.launchAtLogin)
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .font(.caption2)
                }
            }

            // Menu bar display mode picker
            HStack(spacing: 8) {
                Text("Menu Bar:")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Picker("Menu Bar Mode", selection: $monitor.menuBarMode) {
                    ForEach(MenuBarMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }

            // Primary Metrics Grid
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], alignment: .leading, spacing: 10) {
                metric("CPU Usage", "\(monitor.cpuPercent)%", detail: "Clock \(monitor.cpuClock) · P: \(monitor.pcpuLoad) | E: \(monitor.ecpuLoad)", icon: "cpu", color: .blue, history: monitor.cpuHistory)
                metric("CPU Temperature", monitor.cpuTemperature, detail: monitor.temperatureDetail, icon: "thermometer.medium", color: monitor.cpuTempColor)
                metric("Memory", "\(monitor.memoryPercent)%", detail: monitor.memoryDetail, icon: "memorychip", color: .green, history: monitor.memoryHistory)
                metric("GPU Usage", monitor.gpuPercent, detail: "Clock \(monitor.gpuClock)", icon: "square.3.layers.3d", color: .purple, history: monitor.gpuHistory)
                metric("GPU Temperature", monitor.gpuTemperature, detail: "Apple Silicon SoC Thermal Zone", icon: "thermometer.medium", color: .orange)
                metric("Network", monitor.downloadRate, detail: "↑ \(monitor.uploadRate) · Ping \(monitor.pingLatency)", icon: "network", color: .pink, history: monitor.networkHistory, isPercent: false)
                metric("Internal Disk", "R \(monitor.diskReadRate)", detail: "W \(monitor.diskWriteRate) · \(monitor.diskDetail)", icon: "internaldrive", color: .cyan)
                metric("Cooling & Fans", monitor.fanSpeed, detail: "Dual Apple Silicon fans", icon: "fanblades.fill", color: .teal)
                metric("Battery Level", monitor.batteryLevel, detail: "\(monitor.batteryState) · Rem: \(monitor.batteryRemaining)", icon: "battery.75percent", color: .green)
                metric("Battery Power", monitor.powerWatts, detail: "Current \(monitor.currentAmps) · \(monitor.powerState)", icon: "bolt.fill", color: .orange)
                metric("Battery Health", monitor.batteryHealth, detail: "Cycles: \(monitor.batteryCycles) · Temp: \(monitor.batteryTemp)", icon: "heart.fill", color: .red)
                metric("Refresh Rate", "\(monitor.refreshInterval)s", detail: "Live sensors ≤1s · Ping 3s", icon: "arrow.clockwise", color: .indigo)
            }

            // Top Processes Section
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "list.bullet.rectangle.portrait")
                        .foregroundStyle(Color.accentColor)
                    Text("Top Resource Processes")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                if monitor.topProcesses.isEmpty {
                    Text("Sampling active processes…")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.vertical, 4)
                } else {
                    ForEach(monitor.topProcesses) { proc in
                        HStack(spacing: 8) {
                            Text(proc.name)
                                .font(.caption.weight(.medium))
                                .lineLimit(1)
                            Spacer()
                            Text(String(format: "%.1f%% CPU", proc.cpuPercent))
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(proc.cpuPercent > 30 ? .orange : .secondary)
                            Text(String(format: "%.1f%% RAM", proc.memPercent))
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                }
            }
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.72), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
            }

            Divider()

            // Footer controls
            HStack(spacing: 12) {
                Label("Refresh", systemImage: "timer")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("Refresh interval", selection: $monitor.refreshInterval) {
                    Text("1s").tag(1)
                    Text("2s").tag(2)
                    Text("5s").tag(5)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 140)

                Spacer()

                HStack(spacing: 5) {
                    Circle()
                        .fill(monitor.sensorsAreLive ? Color.green : Color.orange)
                        .frame(width: 7, height: 7)
                    Text(monitor.statusText)
                        .font(.caption2)
                        .foregroundStyle(monitor.sensorsAreLive ? Color.secondary : Color.orange)
                        .lineLimit(1)
                }

                Button("Quit") { NSApplication.shared.terminate(nil) }
                    .keyboardShortcut("q")
                    .controlSize(.small)
            }
        }
        .padding(14)
        .frame(width: 460)
    }

    @ViewBuilder
    private func metric(
        _ title: String,
        _ value: String,
        detail: String,
        icon: String,
        color: Color,
        history: [Double]? = nil,
        isPercent: Bool = true
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .monospacedDigit()
                    .lineLimit(1)

                if let history, history.count > 1 {
                    SparklineView(data: history, color: color, isPercent: isPercent)
                }

                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 82, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.72), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
        }
    }
}

@MainActor
@Observable
private final class SystemMonitor {
    var cpuPercent = 0
    var cpuClock = "-- GHz"
    var cpuTemperature = "Measuring…"
    var pcpuLoad = "--%"
    var ecpuLoad = "--%"
    var memoryPercent = 0
    var memoryDetail = "Measuring…"
    var gpuPercent = "--%"
    var gpuClock = "-- GHz"
    var gpuTemperature = "Measuring…"
    var temperatureDetail = "Waiting for sensor stream"
    var downloadRate = "↓ --"
    var uploadRate = "--"
    var pingLatency = "-- ms"
    var diskDetail = "Measuring…"
    var diskReadRate = "--"
    var diskWriteRate = "--"
    var fanSpeed = "0 RPM · Silent"
    var batteryLevel = "--"
    var batteryState = "Reading power source…"
    var batteryRemaining = "Calculating…"
    var powerWatts = "Measuring…"
    var currentAmps = "Measuring…"
    var powerState = "Reading battery sensor"
    var batteryHealth = "--%"
    var batteryCycles = "--"
    var batteryTemp = "-- °C"
    var uptime = "Up --"
    var statusText = "Starting sensors…"
    var sensorsAreLive = false

    var topProcesses: [TopProcessItem] = []

    var cpuHistory: [Double] = []
    var memoryHistory: [Double] = []
    var gpuHistory: [Double] = []
    var networkHistory: [Double] = []

    var menuBarMode: MenuBarMode {
        didSet {
            UserDefaults.standard.set(menuBarMode.rawValue, forKey: Self.menuBarModeKey)
        }
    }

    var launchAtLogin: Bool {
        get {
            SMAppService.mainApp.status == .enabled
        }
        set {
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                fputs("Launch at login error: \(error)\n", stderr)
            }
        }
    }

    var cpuTempColor: Color {
        guard let numStr = cpuTemperature.split(separator: " ").first,
              let val = Double(numStr) else { return .red }
        if val > 80 { return .red }
        if val > 65 { return .orange }
        return .blue
    }

    var refreshInterval: Int {
        didSet {
            guard refreshInterval != oldValue else { return }
            UserDefaults.standard.set(refreshInterval, forKey: Self.refreshKey)
            restartMonitoring()
        }
    }

    private static let refreshKey = "refreshInterval"
    private static let menuBarModeKey = "menuBarDisplayMode"
    private let collector = SensorCollector()
    private var monitoringTask: Task<Void, Never>?

    init() {
        let savedInterval = UserDefaults.standard.integer(forKey: Self.refreshKey)
        refreshInterval = [1, 2, 5].contains(savedInterval) ? savedInterval : 2

        let savedMode = UserDefaults.standard.string(forKey: Self.menuBarModeKey) ?? ""
        menuBarMode = MenuBarMode(rawValue: savedMode) ?? .power

        restartMonitoring()
    }

    private func restartMonitoring() {
        monitoringTask?.cancel()
        let interval = refreshInterval
        monitoringTask = Task { [weak self] in
            guard let self else { return }
            await self.collector.configure(interval: interval)
            while !Task.isCancelled {
                let snapshot = await self.collector.sample()
                guard !Task.isCancelled else { return }
                self.apply(snapshot)
                do {
                    try await Task.sleep(for: .seconds(interval))
                } catch {
                    return
                }
            }
        }
    }

    private func apply(_ snapshot: SensorSnapshot) {
        cpuPercent = snapshot.cpuPercent
        cpuClock = snapshot.cpuClock
        cpuTemperature = snapshot.cpuTemperature
        pcpuLoad = snapshot.pcpuLoad
        ecpuLoad = snapshot.ecpuLoad
        memoryPercent = snapshot.memoryPercent
        memoryDetail = snapshot.memoryDetail
        gpuPercent = snapshot.gpuPercent
        gpuClock = snapshot.gpuClock
        gpuTemperature = snapshot.gpuTemperature
        temperatureDetail = snapshot.temperatureDetail
        downloadRate = snapshot.downloadRate
        uploadRate = snapshot.uploadRate
        pingLatency = snapshot.pingLatency
        diskDetail = snapshot.diskDetail
        diskReadRate = snapshot.diskReadRate
        diskWriteRate = snapshot.diskWriteRate
        fanSpeed = snapshot.fanSpeed
        batteryLevel = snapshot.batteryLevel
        batteryState = snapshot.batteryState
        batteryRemaining = snapshot.batteryRemaining
        powerWatts = snapshot.powerWatts
        currentAmps = snapshot.currentAmps
        powerState = snapshot.powerState
        batteryHealth = snapshot.batteryHealth
        batteryCycles = snapshot.batteryCycles
        batteryTemp = snapshot.batteryTemp
        uptime = snapshot.uptime
        sensorsAreLive = snapshot.sensorsAreLive
        statusText = snapshot.statusText
        topProcesses = snapshot.topProcesses

        // Update rolling sparkline histories (keep max 20 samples)
        cpuHistory.append(Double(snapshot.cpuPercent))
        if cpuHistory.count > 20 { cpuHistory.removeFirst() }

        memoryHistory.append(Double(snapshot.memoryPercent))
        if memoryHistory.count > 20 { memoryHistory.removeFirst() }

        if let gpuNum = Double(snapshot.gpuPercent.replacingOccurrences(of: "%", with: "")) {
            gpuHistory.append(gpuNum)
            if gpuHistory.count > 20 { gpuHistory.removeFirst() }
        }

        networkHistory.append(snapshot.rawDownloadBytes)
        if networkHistory.count > 20 { networkHistory.removeFirst() }
    }
}

private actor SensorCollector {
    private let macmon = MacmonSampler(intervalMilliseconds: 1_000)
    private var configuredInterval = 2
    private var lastMacmonTimestamp: String?
    private var cpuTemperatureHistory: [Double] = []
    private var gpuTemperatureHistory: [Double] = []
    private var lastValidCPUTemperatureAt: Date?
    private var lastValidGPUTemperatureAt: Date?
    private var lastCPUTicks: (busy: UInt64, total: UInt64)?
    private var defaultInterface: String?
    private var lastInterfaceCheck = Date.distantPast
    private var lastNetwork: (interface: String, received: UInt64, sent: UInt64, time: Date)?
    private var networkRates = (download: "--", upload: "--", rawDown: 0.0)
    private var lastDisk: (read: UInt64, written: UInt64, time: Date)?
    private var diskRates = (read: "--", written: "--")
    private var lastPingCheck = Date.distantPast
    private var cachedPing = "-- ms"

    func configure(interval: Int) {
        configuredInterval = interval
        macmon.setInterval(milliseconds: 1_000)
    }

    func sample() async -> SensorSnapshot {
        let now = Date.now
        let reading = macmon.latest()
        let readingAge = reading.map { now.timeIntervalSince($0.receivedAt) }
        let sensorsLive = readingAge.map { $0 <= Double(max(6, configuredInterval * 3)) } ?? false

        if let reading, reading.metrics.timestamp != lastMacmonTimestamp {
            lastMacmonTimestamp = reading.metrics.timestamp
            recordTemperatures(reading.metrics.temp, at: reading.receivedAt)
        }

        let cpu = cpuValues(from: sensorsLive ? reading?.metrics : nil)
        let memory = memoryValues()
        let gpu = gpuValues(from: sensorsLive ? reading?.metrics : nil)
        let temperatures = temperatureValues(now: now)
        let network = updateNetwork(now: now)
        let disk = updateDisk(now: now)
        let battery = readBattery()
        let fans = fanValues(from: sensorsLive ? reading?.metrics : nil)
        let ping = await updatePing(now: now)
        let procs = sampleTopProcesses()

        let status: String
        if sensorsLive {
            status = "Live · \(now.formatted(date: .omitted, time: .standard))"
        } else if macmon.isAvailable {
            status = "Sensors connecting…"
        } else {
            status = "Helper offline"
        }

        return SensorSnapshot(
            cpuPercent: cpu.percent,
            cpuClock: cpu.clock,
            cpuTemperature: temperatures.cpu,
            pcpuLoad: cpu.pcpu,
            ecpuLoad: cpu.ecpu,
            memoryPercent: memory.percent,
            memoryDetail: memory.detail,
            gpuPercent: gpu.percent,
            gpuClock: gpu.clock,
            gpuTemperature: temperatures.gpu,
            temperatureDetail: temperatures.detail,
            downloadRate: "↓ \(network.download)",
            uploadRate: network.upload,
            rawDownloadBytes: network.rawDown,
            pingLatency: ping,
            diskDetail: disk.detail,
            diskReadRate: disk.read,
            diskWriteRate: disk.written,
            fanSpeed: fans,
            batteryLevel: battery.level,
            batteryState: battery.state,
            batteryRemaining: battery.remaining,
            powerWatts: battery.watts,
            currentAmps: battery.current,
            powerState: battery.powerState,
            batteryHealth: battery.health,
            batteryCycles: battery.cycles,
            batteryTemp: battery.temp,
            uptime: ProcessInfo.processInfo.systemUptime.formattedUptime,
            sensorsAreLive: sensorsLive,
            statusText: status,
            topProcesses: procs
        )
    }

    private func cpuValues(from metrics: MacmonMetrics?) -> (percent: Int, clock: String, pcpu: String, ecpu: String) {
        let percent = fallbackCPUUsage()
        guard let metrics else { return (percent, "-- GHz", "--%", "--%") }
        let clock = metrics.pcpuFreqMHz > 0 ? String(format: "%.2f GHz", Double(metrics.pcpuFreqMHz) / 1_000) : "Idle"
        let pcpu = Int((metrics.pcpuActiveRatio * 100).rounded()).clamped(to: 0...100)
        let ecpu = Int((metrics.ecpuActiveRatio * 100).rounded()).clamped(to: 0...100)
        return (percent, clock, "\(pcpu)%", "\(ecpu)%")
    }

    private func gpuValues(from metrics: MacmonMetrics?) -> (percent: String, clock: String) {
        guard let metrics else { return ("--%", "-- GHz") }
        let percent = Int((metrics.gpuActiveRatio * 100).rounded()).clamped(to: 0...100)
        let clock = metrics.gpuFreqMHz > 0 ? String(format: "%.2f GHz", Double(metrics.gpuFreqMHz) / 1_000) : "Idle"
        return ("\(percent)%", clock)
    }

    private func fanValues(from metrics: MacmonMetrics?) -> String {
        guard let fans = metrics?.fans, !fans.isEmpty else { return "0 RPM · Silent" }
        let r0 = fans.indices.contains(0) ? fans[0].rpm : 0
        let r1 = fans.indices.contains(1) ? fans[1].rpm : 0
        return formattedFanSpeed(rpm0: r0, rpm1: r1)
    }

    private func memoryValues() -> (percent: Int, detail: String) {
        fallbackMemoryUsage()
    }

    private func recordTemperatures(_ temperature: MacmonMetrics.Temperature, at date: Date) {
        if let effectiveCPU = resolvedCPUTemperature(cpu: temperature.cpu, gpu: temperature.gpu) {
            cpuTemperatureHistory.append(effectiveCPU)
            cpuTemperatureHistory = Array(cpuTemperatureHistory.suffix(3))
            lastValidCPUTemperatureAt = date
        }
        if isValidTemperature(temperature.gpu) {
            gpuTemperatureHistory.append(temperature.gpu)
            gpuTemperatureHistory = Array(gpuTemperatureHistory.suffix(3))
            lastValidGPUTemperatureAt = date
        }
    }

    private func temperatureValues(now: Date) -> (cpu: String, gpu: String, detail: String) {
        let maxAge = Double(max(12, configuredInterval * 4))
        let cpuFresh = lastValidCPUTemperatureAt.map { now.timeIntervalSince($0) <= maxAge } ?? false
        let gpuFresh = lastValidGPUTemperatureAt.map { now.timeIntervalSince($0) <= maxAge } ?? false
        let cpu = cpuFresh ? median(cpuTemperatureHistory).map { String(format: "%.1f °C", $0) } ?? "Measuring…" : "Unavailable"
        let gpu = gpuFresh ? median(gpuTemperatureHistory).map { String(format: "%.1f °C", $0) } ?? "Measuring…" : "Unavailable"
        let detail = cpuFresh && gpuFresh ? "Rolling sensor median" : (cpuFresh || gpuFresh ? "Active sensor reading" : "Waiting for valid sensor data")
        return (cpu, gpu, detail)
    }

    private func updateNetwork(now: Date) -> (download: String, upload: String, rawDown: Double) {
        if now.timeIntervalSince(lastInterfaceCheck) > 30 || defaultInterface == nil {
            lastInterfaceCheck = now
            defaultInterface = runShell("/sbin/route -n get default 2>/dev/null | /usr/bin/awk '/interface:/{print $2}'")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard let interface = defaultInterface, !interface.isEmpty,
              let counters = networkCounters(for: interface) else {
            lastNetwork = nil
            networkRates = ("Offline", "--", 0.0)
            return networkRates
        }
        if let last = lastNetwork,
           last.interface == interface,
           counters.received >= last.received,
           counters.sent >= last.sent {
            let elapsed = now.timeIntervalSince(last.time)
            if elapsed > 0 {
                let downBytes = Double(counters.received - last.received) / elapsed
                let upBytes = Double(counters.sent - last.sent) / elapsed
                networkRates = (
                    formattedRate(downBytes),
                    formattedRate(upBytes),
                    downBytes
                )
            }
        } else {
            networkRates = ("--", "--", 0.0)
        }
        lastNetwork = (interface, counters.received, counters.sent, now)
        return networkRates
    }

    private func updatePing(now: Date) async -> String {
        guard now.timeIntervalSince(lastPingCheck) > 3.0 else { return cachedPing }
        lastPingCheck = now
        let output = runShell("/sbin/ping -c 1 -W 600 1.1.1.1 2>/dev/null | /usr/bin/grep -o -E 'time=[0-9.]+' | /usr/bin/cut -d= -f2")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let ms = Double(output) {
            cachedPing = String(format: "%.0f ms", ms)
        }
        return cachedPing
    }

    private func sampleTopProcesses() -> [TopProcessItem] {
        let output = runShell("/bin/ps -Aceo pid,pcpu,pmem,comm -r | head -n 5")
        return parseTopProcesses(from: output, maxCount: 4)
    }

    private func updateDisk(now: Date) -> (read: String, written: String, detail: String) {
        if let counters = internalDiskCounters() {
            if let last = lastDisk, counters.read >= last.read, counters.written >= last.written {
                let elapsed = now.timeIntervalSince(last.time)
                if elapsed > 0 {
                    diskRates = (
                        formattedRate(Double(counters.read - last.read) / elapsed),
                        formattedRate(Double(counters.written - last.written) / elapsed)
                    )
                }
            } else {
                diskRates = ("--", "--")
            }
            lastDisk = (counters.read, counters.written, now)
        }

        let detail: String
        if let values = try? URL(fileURLWithPath: "/").resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]),
           let total = values.volumeTotalCapacity,
           let free = values.volumeAvailableCapacityForImportantUsage,
           total > 0 {
            let used = Int64(total) - free
            detail = "\(Int(Double(used) / Double(total) * 100))% used · \(free.gigabytes) GB free"
        } else {
            detail = "Capacity unavailable"
        }
        return (diskRates.read, diskRates.written, detail)
    }

    private func readBattery() -> (
        level: String,
        state: String,
        remaining: String,
        watts: String,
        current: String,
        powerState: String,
        health: String,
        cycles: String,
        temp: String
    ) {
        var level = "--"
        var state = "No battery"
        var remaining = "Calculating…"
        var health = "--%"
        var cycles = "--"
        var temp = "-- °C"

        if let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() {
            let sources = IOPSCopyPowerSourcesList(blob).takeRetainedValue() as [CFTypeRef]
            if let source = sources.first,
               let description = IOPSGetPowerSourceDescription(blob, source).takeUnretainedValue() as? [String: Any] {
                if let capacity = description[kIOPSCurrentCapacityKey] as? Int { level = "\(capacity)%" }
                let charging = description[kIOPSIsChargingKey] as? Bool ?? false
                let pluggedIn = (description[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
                state = charging ? "Charging" : (pluggedIn ? "Power adapter" : "On battery")
            }
        }

        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != IO_OBJECT_NULL else {
            return (level, state, remaining, "Unavailable", "Unavailable", "Battery sensor unavailable", health, cycles, temp)
        }
        defer { IOObjectRelease(service) }

        guard let currentNumber = registryNumber(service: service, key: "InstantAmperage"),
              let voltageNumber = registryNumber(service: service, key: "Voltage") else {
            return (level, state, remaining, "Unavailable", "Unavailable", "Battery sensor unavailable", health, cycles, temp)
        }

        let cycleNumber = registryNumber(service: service, key: "CycleCount")?.intValue ?? 0
        cycles = "\(cycleNumber)"

        let maxCap = registryNumber(service: service, key: "AppleRawMaxCapacity")?.intValue ?? (registryNumber(service: service, key: "MaxCapacity")?.intValue ?? 0)
        let designCap = registryNumber(service: service, key: "DesignCapacity")?.intValue ?? 0
        if let hScore = batteryHealthScore(maxCap: maxCap, designCap: designCap) {
            health = "\(hScore)%"
        }

        let tempRaw = registryNumber(service: service, key: "Temperature")?.intValue ?? 0
        if let tempC = batteryTemperatureCelsius(rawTemp: tempRaw) {
            temp = String(format: "%.1f °C", tempC)
        }

        let timeRemainingVal = registryNumber(service: service, key: "AvgTimeToEmpty")?.intValue ?? (registryNumber(service: service, key: "TimeRemaining")?.intValue ?? 0)
        remaining = formattedBatteryRemaining(minutes: timeRemainingVal)

        let milliamps = Int64(bitPattern: currentNumber.uint64Value)
        let millivolts = voltageNumber.doubleValue
        let watts = batteryPowerWatts(milliamps: milliamps, millivolts: millivolts)
        let external = registryNumber(service: service, key: "ExternalConnected")?.boolValue ?? false
        let formatted = abs(watts) < 0.05 ? "0.0 W" : String(format: "%@%.1f W", watts > 0 ? "+" : "−", abs(watts))
        let formattedCurrent = abs(milliamps) >= 1_000
            ? String(format: "%@%.2f A", milliamps >= 0 ? "+" : "−", abs(Double(milliamps)) / 1_000)
            : String(format: "%@%lld mA", milliamps >= 0 ? "+" : "−", abs(milliamps))
        let voltage = String(format: "%.2f V", millivolts / 1_000)
        let powerState: String
        if watts > 0.2 { powerState = "Charging · \(voltage)" }
        else if watts < -0.2 { powerState = "Discharging · \(voltage)" }
        else if external { powerState = "Plugged in · idle" }
        else { powerState = "Battery idle · \(voltage)" }

        return (level, state, remaining, formatted, formattedCurrent, powerState, health, cycles, temp)
    }

    private func fallbackCPUUsage() -> Int {
        var processors: processor_info_array_t?
        var processorCount: mach_msg_type_number_t = 0
        var infoCount: mach_msg_type_number_t = 0
        guard host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &processorCount, &processors, &infoCount) == KERN_SUCCESS,
              let info = processors else { return 0 }
        defer { vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), vm_size_t(infoCount) * vm_size_t(MemoryLayout<integer_t>.stride)) }
        var busy: UInt64 = 0, total: UInt64 = 0
        for index in 0..<Int(processorCount) {
            let base = index * Int(CPU_STATE_MAX)
            let user = UInt64(info[base + Int(CPU_STATE_USER)])
            let system = UInt64(info[base + Int(CPU_STATE_SYSTEM)])
            let nice = UInt64(info[base + Int(CPU_STATE_NICE)])
            let idle = UInt64(info[base + Int(CPU_STATE_IDLE)])
            busy += user + system + nice
            total += user + system + nice + idle
        }
        defer { lastCPUTicks = (busy, total) }
        guard let previous = lastCPUTicks, total > previous.total else { return 0 }
        let deltaTotal = total - previous.total
        return deltaTotal == 0 ? 0 : Int((Double(busy - previous.busy) / Double(deltaTotal) * 100).rounded()).clamped(to: 0...100)
    }

    private func fallbackMemoryUsage() -> (percent: Int, detail: String) {
        let total = ProcessInfo.processInfo.physicalMemory
        var info = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS, total > 0 else { return (0, "Unavailable") }
        let pageSize = UInt64(sysconf(Int32(_SC_PAGESIZE)))
        let usedPages = UInt64(info.active_count + info.wire_count + info.compressor_page_count)
        let used = min(total, usedPages * pageSize)
        let percent = Int((Double(used) / Double(total) * 100).rounded()).clamped(to: 0...100)
        return (percent, "\(used.gigabytes) / \(total.gigabytes) GB")
    }
}

private final class MacmonSampler: @unchecked Sendable {
    struct Reading: Sendable {
        let metrics: MacmonMetrics
        let receivedAt: Date
    }

    private let lock = NSLock()
    private var process: Process?
    private var outputPipe: Pipe?
    private var buffer = Data()
    private var latestReading: Reading?
    private var intervalMilliseconds: Int
    private var available = false

    var isAvailable: Bool {
        lock.lock()
        defer { lock.unlock() }
        return available
    }

    init(intervalMilliseconds: Int) {
        self.intervalMilliseconds = intervalMilliseconds
        start()
    }

    deinit {
        stop()
    }

    func setInterval(milliseconds: Int) {
        lock.lock()
        let changed = milliseconds != intervalMilliseconds
        intervalMilliseconds = milliseconds
        lock.unlock()
        if changed {
            stop()
            start()
        }
    }

    func latest() -> Reading? {
        lock.lock()
        let reading = latestReading
        let running = process?.isRunning == true
        lock.unlock()
        if !running { start() }
        return reading
    }

    private func start() {
        lock.lock()
        if process?.isRunning == true {
            lock.unlock()
            return
        }
        let interval = intervalMilliseconds
        lock.unlock()

        guard let executable = macmonExecutablePath() else {
            lock.lock(); available = false; lock.unlock()
            return
        }

        let task = Process()
        let pipe = Pipe()
        task.executableURL = URL(fileURLWithPath: executable)
        task.arguments = ["pipe", "--samples", "0", "--interval", "\(interval)"]
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            self?.consume(data)
        }
        do {
            try task.run()
            lock.lock()
            process = task
            outputPipe = pipe
            available = true
            lock.unlock()
        } catch {
            pipe.fileHandleForReading.readabilityHandler = nil
            lock.lock(); available = false; lock.unlock()
        }
    }

    private func stop() {
        lock.lock()
        let task = process
        let pipe = outputPipe
        process = nil
        outputPipe = nil
        buffer.removeAll(keepingCapacity: false)
        lock.unlock()
        pipe?.fileHandleForReading.readabilityHandler = nil
        if task?.isRunning == true { task?.terminate() }
    }

    private func consume(_ data: Data) {
        var lines: [Data] = []
        lock.lock()
        buffer.append(data)
        while let newline = buffer.firstIndex(of: 0x0A) {
            lines.append(buffer.subdata(in: buffer.startIndex..<newline))
            buffer.removeSubrange(buffer.startIndex...newline)
        }
        lock.unlock()

        for line in lines where !line.isEmpty {
            guard let metrics = try? JSONDecoder().decode(MacmonMetrics.self, from: line) else { continue }
            lock.lock()
            latestReading = Reading(metrics: metrics, receivedAt: .now)
            lock.unlock()
        }
    }
}

private struct SensorSnapshot: Sendable {
    let cpuPercent: Int
    let cpuClock: String
    let cpuTemperature: String
    let pcpuLoad: String
    let ecpuLoad: String
    let memoryPercent: Int
    let memoryDetail: String
    let gpuPercent: String
    let gpuClock: String
    let gpuTemperature: String
    let temperatureDetail: String
    let downloadRate: String
    let uploadRate: String
    let rawDownloadBytes: Double
    let pingLatency: String
    let diskDetail: String
    let diskReadRate: String
    let diskWriteRate: String
    let fanSpeed: String
    let batteryLevel: String
    let batteryState: String
    let batteryRemaining: String
    let powerWatts: String
    let currentAmps: String
    let powerState: String
    let batteryHealth: String
    let batteryCycles: String
    let batteryTemp: String
    let uptime: String
    let sensorsAreLive: Bool
    let statusText: String
    let topProcesses: [TopProcessItem]
}

struct MacmonMetrics: Decodable, Sendable {
    struct Temperature: Decodable, Sendable {
        let cpu: Double
        let gpu: Double
        enum CodingKeys: String, CodingKey { case cpu = "cpu_temp_avg", gpu = "gpu_temp_avg" }
    }

    struct Fan: Decodable, Sendable {
        let name: String
        let rpm: Int
        let max_rpm: Int?
    }

    let timestamp: String
    let temp: Temperature
    let pcpuFreqMHz: Int
    let gpuFreqMHz: Int
    let gpuActiveRatio: Double
    let ecpuActiveRatio: Double
    let pcpuActiveRatio: Double
    let fans: [Fan]?

    enum CodingKeys: String, CodingKey {
        case timestamp, temp, fans
        case pcpuFreqMHz = "pcpu_freq_mhz"
        case gpuFreqMHz = "gpu_freq_mhz"
        case gpuActiveRatio = "gpu_active_ratio"
        case ecpuActiveRatio = "ecpu_active_ratio"
        case pcpuActiveRatio = "pcpu_active_ratio"
    }
}

private func networkCounters(for interface: String) -> (received: UInt64, sent: UInt64)? {
    var addresses: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&addresses) == 0, let first = addresses else { return nil }
    defer { freeifaddrs(addresses) }
    var cursor: UnsafeMutablePointer<ifaddrs>? = first
    while let current = cursor {
        let entry = current.pointee
        if String(cString: entry.ifa_name) == interface,
           entry.ifa_addr?.pointee.sa_family == UInt8(AF_LINK),
           let rawData = entry.ifa_data {
            let data = rawData.assumingMemoryBound(to: if_data.self).pointee
            return (UInt64(data.ifi_ibytes), UInt64(data.ifi_obytes))
        }
        cursor = entry.ifa_next
    }
    return nil
}

private func internalDiskCounters() -> (read: UInt64, written: UInt64)? {
    let output = runShell("/usr/sbin/ioreg -r -c AppleANS2NVMeController -l -w0 | /usr/bin/grep -o -E '\"Bytes (read|written) from block device\"=[0-9]+'")
    var read: UInt64 = 0
    var written: UInt64 = 0
    for line in output.split(separator: "\n") {
        let pieces = line.split(separator: "=", maxSplits: 1)
        guard pieces.count == 2, let value = UInt64(pieces[1]) else { continue }
        if line.contains("Bytes read") { read = max(read, value) }
        if line.contains("Bytes written") { written = max(written, value) }
    }
    return read > 0 || written > 0 ? (read, written) : nil
}

private func registryNumber(service: io_service_t, key: String) -> NSNumber? {
    guard let value = IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() else { return nil }
    return value as? NSNumber
}

private func macmonExecutablePath() -> String? {
    let bundled = Bundle.main.resourceURL?.appendingPathComponent("macmon").path
    let candidates = [bundled, "/opt/homebrew/bin/macmon", "/usr/local/bin/macmon"].compactMap { $0 }
    return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
}

private func runShell(_ command: String) -> String {
    let task = Process()
    let pipe = Pipe()
    task.executableURL = URL(fileURLWithPath: "/bin/sh")
    task.arguments = ["-c", command]
    task.standardOutput = pipe
    task.standardError = FileHandle.nullDevice
    do {
        try task.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        return String(data: data, encoding: .utf8) ?? ""
    } catch {
        return ""
    }
}

private extension UInt64 {
    var gigabytes: String { String(format: "%.1f", Double(self) / 1_073_741_824) }
}

private extension Int64 {
    var gigabytes: String { String(format: "%.1f", Double(self) / 1_073_741_824) }
}

private extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int { Swift.min(Swift.max(self, range.lowerBound), range.upperBound) }
}

private extension TimeInterval {
    var formattedUptime: String {
        let days = Int(self) / 86_400
        let hours = (Int(self) % 86_400) / 3_600
        return days > 0 ? "Up \(days)d \(hours)h" : "Up \(hours)h"
    }
}

