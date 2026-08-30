import Foundation
import SystemPulseCore

struct CheckFailure: Error { let message: String }

func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw CheckFailure(message: message) }
}

do {
    try require(formattedRate(512) == "512 B/s", "byte formatting")
    try require(formattedRate(2_048) == "2 KB/s", "kilobyte formatting")
    try require(formattedRate(1_572_864) == "1.5 MB/s", "megabyte formatting")
    try require(median([32, 14, 33]) == 32, "temperature median")
    try require(!isValidTemperature(14) && !isValidTemperature(5.9), "invalid temperature filter")
    try require(isValidTemperature(33), "valid temperature filter")
    try require(resolvedCPUTemperature(cpu: 14.5, gpu: 44.8) == 44.8, "apple silicon idle cpu fallback to SoC die")
    try require(resolvedCPUTemperature(cpu: 52.0, gpu: 45.0) == 52.0, "active cpu temperature")
    try require(resolvedCPUTemperature(cpu: 32.0, gpu: 10.0) == 32.0, "valid cpu with invalid gpu")
    try require(resolvedCPUTemperature(cpu: 14.0, gpu: 12.0) == nil, "both invalid temperatures")
    try require(abs(batteryPowerWatts(milliamps: -774, millivolts: 11_435) - -8.85069) < 0.00001, "discharge power")
    try require(formattedBatteryRemaining(minutes: 228) == "3h 48m", "battery remaining format")
    try require(formattedBatteryRemaining(minutes: 45) == "45m", "battery remaining minutes format")
    try require(batteryHealthScore(maxCap: 8521, designCap: 8694) == 98, "battery health calculation")
    if let bTemp = batteryTemperatureCelsius(rawTemp: 3082) {
        try require(abs(bTemp - 35.05) < 0.1, "battery temp conversion")
    } else {
        throw CheckFailure(message: "battery temp conversion returned nil")
    }
    try require(formattedFanSpeed(rpm0: 0, rpm1: 0) == "0 RPM · Silent", "fan silent format")
    try require(formattedFanSpeed(rpm0: 2100, rpm1: 2250) == "2100 / 2250 RPM", "fan dual rpm format")
    let psMock = """
      PID  %CPU %MEM COMM
      600  37.6  0.8 /System/Library/CoreServices/WindowServer
    28075  25.9  2.0 /opt/homebrew/bin/agy
    """
    let procs = parseTopProcesses(from: psMock)
    try require(procs.count == 2, "process count")
    try require(procs.first?.name == "WindowServer" && procs.first?.cpuPercent == 37.6, "process parsing")
    print("SystemPulse checks passed")
} catch let failure as CheckFailure {
    fputs("SystemPulse check failed: \(failure.message)\n", stderr)
    exit(1)
}
