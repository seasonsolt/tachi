// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EACCMonitor",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "EACCMonitor",
            path: "Sources/EACCMonitor"
        ),
        .testTarget(
            name: "EACCMonitorTests",
            dependencies: ["EACCMonitor"],
            path: "Tests/EACCMonitorTests"
        )
    ]
)
