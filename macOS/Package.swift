// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SystemPulseMac",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "SystemPulseMac", targets: ["SystemPulseMac"])],
    targets: [
        .target(name: "SystemPulseCore"),
        .executableTarget(name: "SystemPulseMac", dependencies: ["SystemPulseCore"]),
        .executableTarget(name: "SystemPulseChecks", dependencies: ["SystemPulseCore"])
    ]
)
