// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Pavement",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PavementCore",
            targets: ["PavementCore"]
        ),
        .library(
            name: "PavementUI",
            targets: ["PavementUI"]
        )
    ],
    targets: [
        .target(
            name: "PavementCore",
            path: "Sources/PavementCore",
            resources: [
                .process("Filters/Metal")
            ]
        ),
        .target(
            name: "PavementUI",
            dependencies: ["PavementCore"],
            path: "Sources/PavementUI"
        ),
        .testTarget(
            name: "PavementCoreTests",
            dependencies: ["PavementCore"],
            path: "Tests/PavementCoreTests",
            resources: [
                .copy("Fixtures")
            ]
        )
    ]
)
