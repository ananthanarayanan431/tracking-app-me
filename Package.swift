// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Spent",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Spent",
            dependencies: ["DeskBreakKit", "AadatKit"],
            path: "Sources/Spent",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),

        // DeskBreak (water / walk reminders), from github.com/ananthanarayanan431/deskbreak @ 2b833f4.
        // Core is copied unchanged; Kit is the app layer, adapted only to run inside Spent.
        .target(name: "DeskBreakCore", path: "Sources/DeskBreakCore"),
        .target(name: "DeskBreakKit", dependencies: ["DeskBreakCore"], path: "Sources/DeskBreakKit"),

        // Aadat (today / tomorrow tasks), from github.com/ananthanarayanan431/Aadat @ bdbb6f7.
        .target(name: "AadatCore", path: "Sources/AadatCore"),
        .target(name: "AadatKit", dependencies: ["AadatCore"], path: "Sources/AadatKit"),

        .testTarget(
            name: "SpentTests",
            dependencies: ["Spent"],
            path: "Tests/SpentTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(name: "DeskBreakCoreTests", dependencies: ["DeskBreakCore"], path: "Tests/DeskBreakCoreTests"),
        .testTarget(name: "AadatCoreTests", dependencies: ["AadatCore"], path: "Tests/AadatCoreTests"),
    ],
    swiftLanguageModes: [.v6]
)
