// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Connections",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Connections",
            path: "Sources/Connections",
            resources: [
                .copy("Resources/Info.plist")
            ],
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        )
    ]
)
