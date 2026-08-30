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
    try require(abs(batteryPowerWatts(milliamps: -774, millivolts: 11_435) - -8.85069) < 0.00001, "discharge power")
    print("SystemPulse checks passed")
} catch let failure as CheckFailure {
    fputs("SystemPulse check failed: \(failure.message)\n", stderr)
    exit(1)
}
