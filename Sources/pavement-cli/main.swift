import ArgumentParser
import PavementCore

@main
struct PavementCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "pavement-cli",
        abstract: "Smoke-test harness for the Pavement engine.",
        version: PavementCore.version,
        subcommands: [Scan.self, Decode.self, Render.self, Export.self]
    )
}

extension PavementCLI {
    struct Scan: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Scan a folder and list detected RAW files. (Phase 1)"
        )

        @Argument(help: "Folder to scan.") var folder: String

        func run() throws {
            throw ValidationError("scan: not yet implemented (Phase 1)")
        }
    }

    struct Decode: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Decode a RAW file and write a PNG. (Phase 1)"
        )

        @Argument(help: "Source RAW file.") var source: String
        @Argument(help: "Destination PNG.") var destination: String

        func run() throws {
            throw ValidationError("decode: not yet implemented (Phase 1)")
        }
    }

    struct Render: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Apply a recipe JSON to a RAW and write the rendered output. (Phase 2)"
        )

        @Option(name: .long, help: "Path to .pavement.json recipe.") var recipe: String
        @Argument(help: "Source RAW file.") var source: String
        @Argument(help: "Destination image.") var destination: String

        func run() throws {
            throw ValidationError("render: not yet implemented (Phase 2)")
        }
    }

    struct Export: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Export a RAW using a named preset. (Phase 3)"
        )

        @Option(name: .long, help: "Preset name (instagram, web, print).") var preset: String
        @Argument(help: "Source RAW file.") var source: String

        func run() throws {
            throw ValidationError("export: not yet implemented (Phase 3)")
        }
    }
}
