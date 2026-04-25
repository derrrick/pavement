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
        ),
        .executable(
            name: "pavement-cli",
            targets: ["pavement-cli"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.4.0")
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
        .executableTarget(
            name: "pavement-cli",
            dependencies: [
                "PavementCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/pavement-cli"
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
