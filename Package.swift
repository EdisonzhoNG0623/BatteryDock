// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "BatteryDock",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "BatteryDock", targets: ["BatteryDock"]),
        .library(name: "BatteryDockCore", targets: ["BatteryDockCore"]),
    ],
    targets: [
        .target(name: "BatteryDockCore"),
        .executableTarget(
            name: "BatteryDock",
            dependencies: ["BatteryDockCore"]
        ),
        .testTarget(
            name: "BatteryDockCoreTests",
            dependencies: ["BatteryDockCore"]
        ),
    ]
)
