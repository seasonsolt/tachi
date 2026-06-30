// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Tachi",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Tachi",
            path: "Sources/Tachi"
        ),
        .testTarget(
            name: "TachiTests",
            dependencies: ["Tachi"],
            path: "Tests/TachiTests"
        )
    ]
)
