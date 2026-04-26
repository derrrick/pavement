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
                // .msl extension (not .metal) so Xcode/SwiftPM don't try
                // to invoke the Metal compiler on it. We compile the
                // source at runtime via MTLDevice.makeLibrary(source:).
                // This avoids requiring the optional Metal Toolchain
                // Xcode component to be installed.
                .copy("Filters/Metal/GrainKernel.msl")
            ]
        ),
        .target(
            name: "PavementUI",
            dependencies: ["PavementCore"],
            path: "Sources/PavementUI",
            resources: [
                // Bundled Inter (SIL OFL, https://rsms.me/inter/) — used
                // for the landing-screen wordmark. Registered at runtime
                // via CTFontManagerRegisterFontsForURL so we don't have
                // to ship Info.plist UIAppFonts entries.
                .copy("Resources/Fonts/InterVariable.ttf")
            ]
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
            dependencies: ["PavementCore", "PavementUI"],
            path: "Tests/PavementCoreTests",
            resources: [
                .copy("Fixtures")
            ]
        )
    ]
)
