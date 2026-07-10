// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Uptend",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Uptend",
            path: "Sources/Uptend",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "UptendTests",
            dependencies: ["Uptend"],
            path: "Tests/UptendTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
