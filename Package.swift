// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EACCSMonitor",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "EACCSMonitor",
            path: "Sources/EACCSMonitor"
        )
    ]
)
