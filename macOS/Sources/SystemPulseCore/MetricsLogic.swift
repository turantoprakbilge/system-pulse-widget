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

public func batteryPowerWatts(milliamps: Int64, millivolts: Double) -> Double {
    millivolts * Double(milliamps) / 1_000_000
}
