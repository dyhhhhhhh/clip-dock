// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "ClipDock",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(name: "ClipDockCore", targets: ["ClipDockCore"]),
        .executable(name: "ClipDock", targets: ["ClipDock"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.10.0"),
    ],
    targets: [
        .target(
            name: "ClipDockCore",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
            ],
        ),
        .executableTarget(
            name: "ClipDock",
            dependencies: ["ClipDockCore"],
        ),
        .testTarget(
            name: "ClipDockCoreTests",
            dependencies: ["ClipDockCore"],
        ),
        .testTarget(
            name: "ClipDockUITests",
            dependencies: [],
        ),
    ],
)
