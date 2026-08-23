// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "ActivityRadar",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "ActivityRadarCore", targets: ["ActivityRadarCore"]),
        .executable(name: "ActivityRadar", targets: ["ActivityRadar"]),
        .executable(name: "ActivityRadarDiagnostics", targets: ["ActivityRadarDiagnostics"]),
        .executable(name: "ActivityRadarSelfTest", targets: ["ActivityRadarSelfTest"])
    ],
    targets: [
        .target(
            name: "ActivityRadarCore",
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        ),
        .executableTarget(
            name: "ActivityRadar",
            dependencies: ["ActivityRadarCore"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("Carbon"),
                .linkedFramework("Security")
            ]
        ),
        .executableTarget(
            name: "ActivityRadarDiagnostics",
            dependencies: ["ActivityRadarCore"]
        ),
        .executableTarget(
            name: "ActivityRadarSelfTest",
            dependencies: ["ActivityRadarCore"]
        ),
        .testTarget(
            name: "ActivityRadarCoreTests",
            dependencies: ["ActivityRadarCore", "ActivityRadar"]
        )
    ]
)
