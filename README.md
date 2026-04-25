# Pavement

A personal Mac-native RAW editor for street photography. Solo build, single user, single Mac.
Targets Fujifilm X-E4 (X-Trans IV) and Canon R5 (CR3).

See [PLAN.md](PLAN.md) for the full design.

## Build

Requirements: Xcode 16+ (macOS 14+ deployment target), Swift 5.10+.

```sh
# Engine + tests + CLI
swift build
swift test
swift run pavement-cli --version

# Full app
xcodebuild -scheme Pavement build

# All of the above
./scripts/ci.sh
```

## Run

Open `Pavement.xcodeproj` in Xcode and run the `Pavement` scheme.

## Layout

- `Package.swift` — defines `PavementCore` (engine), tests, and the `pavement-cli` executable.
- `Sources/PavementCore/` — engine: catalog, document model, edit recipe, pixel pipeline, filters, export.
- `Sources/PavementUI/` — SwiftUI surface: browser, editor, histogram.
- `Sources/pavement-cli/` — small CLI for engine smoke tests (`scan`, `decode`, `render`, `export`).
- `Pavement.xcodeproj` + `Pavement/` — thin app shell that depends on the local SwiftPM package.
- `Tests/PavementCoreTests/` — XCTest coverage for the engine.

## Caveats

- Sidecar atomic writes (`.pavement.json`) use temp-file + `rename(2)`. Storing the source folder in iCloud Drive can sync partial writes; prefer local folders.
- Swift 6 / Xcode 26 toolchains tightened `Sendable` checking around `CIFilter`. `PipelineGraph` is `@MainActor` until the engine is fully isolated.
- If Xcode's local-package reference goes stale: `xcodebuild -resolvePackageDependencies && rm -rf ~/Library/Developer/Xcode/DerivedData/Pavement-*`.
