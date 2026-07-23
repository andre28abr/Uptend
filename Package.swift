// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Uptend",
    platforms: [.macOS(.v14)],
    targets: [
        // Lógica pura, sem SwiftUI/AppKit: modelos/renderizadores do relatório,
        // parser de Markdown, navegador de arquivos, helpers de scanner. Testável
        // isoladamente, sem UI.
        .target(
            name: "UptendCore",
            path: "Sources/UptendCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "Uptend",
            dependencies: ["UptendCore"],
            path: "Sources/Uptend",
            resources: [.copy("Resources/audit-collector.sh")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "UptendTests",
            dependencies: ["Uptend", "UptendCore"],
            path: "Tests/UptendTests",
            resources: [.copy("Fixtures")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
