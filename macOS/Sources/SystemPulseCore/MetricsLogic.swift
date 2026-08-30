import Foundation

public func formattedRate(_ bytesPerSecond: Double) -> String {
    if bytesPerSecond >= 1_073_741_824 { return String(format: "%.1f GB/s", bytesPerSecond / 1_073_741_824) }
    if bytesPerSecond >= 1_048_576 { return String(format: "%.1f MB/s", bytesPerSecond / 1_048_576) }
    if bytesPerSecond >= 1_024 { return String(format: "%.0f KB/s", bytesPerSecond / 1_024) }
    return String(format: "%.0f B/s", max(0, bytesPerSecond))
}

public func median(_ values: [Double]) -> Double? {
    guard !values.isEmpty else { return nil }
    let sorted = values.sorted()
    let middle = sorted.count / 2
    return sorted.count.isMultiple(of: 2) ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
}

public func isValidTemperature(_ value: Double) -> Bool {
    value.isFinite && (20...120).contains(value)
}

public func resolvedCPUTemperature(cpu: Double, gpu: Double) -> Double? {
    if isValidTemperature(cpu) && cpu >= 28.0 {
        return cpu
    }
    if isValidTemperature(gpu) {
        return gpu
    }
    if isValidTemperature(cpu) {
        return cpu
    }
    return nil
}

public func batteryPowerWatts(milliamps: Int64, millivolts: Double) -> Double {
    millivolts * Double(milliamps) / 1_000_000
}

public struct TopProcessItem: Identifiable, Sendable, Equatable {
    public var id: Int { pid }
    public let pid: Int
    public let name: String
    public let cpuPercent: Double
    public let memPercent: Double

    public init(pid: Int, name: String, cpuPercent: Double, memPercent: Double) {
        self.pid = pid
        self.name = name
        self.cpuPercent = cpuPercent
        self.memPercent = memPercent
    }
}

public func parseTopProcesses(from output: String, maxCount: Int = 4) -> [TopProcessItem] {
    var items: [TopProcessItem] = []
    let lines = output.split(separator: "\n")
    for line in lines.dropFirst() {
        let parts = line.split(separator: " ", omittingEmptySubsequences: true)
        guard parts.count >= 4,
              let pid = Int(parts[0]),
              let cpu = Double(parts[1]),
              let mem = Double(parts[2]) else { continue }
        let rawName = parts[3...].joined(separator: " ")
        let cleanName = (rawName as NSString).lastPathComponent
        items.append(TopProcessItem(pid: pid, name: cleanName, cpuPercent: cpu, memPercent: mem))
        if items.count >= maxCount { break }
    }
    return items
}

public func formattedBatteryRemaining(minutes: Int) -> String {
    guard minutes > 0 && minutes < 65535 else { return "Calculating…" }
    let hours = minutes / 60
    let mins = minutes % 60
    return hours > 0 ? "\(hours)h \(mins)m" : "\(mins)m"
}

public func batteryHealthScore(maxCap: Int, designCap: Int) -> Int? {
    guard designCap > 0, maxCap > 0 else { return nil }
    return min(100, Int((Double(maxCap) / Double(designCap) * 100).rounded()))
}

public func batteryTemperatureCelsius(rawTemp: Int) -> Double? {
    guard rawTemp > 0 else { return nil }
    if rawTemp > 1000 {
        let c = Double(rawTemp) / 10.0 - 273.15
        return (0...80).contains(c) ? c : nil
    } else if rawTemp > 200 {
        let c = Double(rawTemp) - 273.15
        return (0...80).contains(c) ? c : nil
    }
    let c = Double(rawTemp) / 10.0
    return (0...80).contains(c) ? c : nil
}

public func formattedFanSpeed(rpm0: Int, rpm1: Int) -> String {
    if rpm0 == 0 && rpm1 == 0 {
        return "0 RPM · Silent"
    }
    if rpm0 > 0 && rpm1 > 0 {
        return "\(rpm0) / \(rpm1) RPM"
    }
    let active = max(rpm0, rpm1)
    return "\(active) RPM"
}


