// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Spent",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Spent",
            path: "Sources/Spent"
        ),
        .testTarget(
            name: "SpentTests",
            dependencies: ["Spent"],
            path: "Tests/SpentTests"
        )
    ]
)
