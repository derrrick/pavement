import ArgumentParser
import Foundation
import PavementCore

@main
struct PavementCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "pavement-cli",
        abstract: "Smoke-test harness for the Pavement engine.",
        version: PavementCore.version,
        subcommands: [Scan.self, Decode.self, Thumbnails.self, Render.self, Export.self]
    )
}

extension PavementCLI {
    struct Scan: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Scan a folder and list detected RAW files."
        )

        @Argument(help: "Folder to scan.") var folder: String

        func run() throws {
            let folderURL = URL(fileURLWithPath: (folder as NSString).expandingTildeInPath)
            let scanner = FolderScanner()
            let exif = ExifReader()
            let items = try scanner.scan(folder: folderURL)

            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime]
            dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)

            var rawCount = 0
            for item in items where item.type.isIngestible {
                if item.type.isRaw { rawCount += 1 }
                let exifData = exif.read(url: item.url)
                let date = exifData?.captureTime.map { dateFormatter.string(from: $0) } ?? "—"
                let camera = exifData?.camera ?? "—"
                let typeLabel = item.type.rawValue.uppercased().padding(toLength: 4, withPad: " ", startingAt: 0)
                print("\(typeLabel) \(date)  \(camera.padding(toLength: 20, withPad: " ", startingAt: 0))  \(item.url.path)")
            }
            print("---")
            print("\(items.count) ingestible files (\(rawCount) RAW) under \(folderURL.path)")
        }
    }

    struct Decode: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Decode a source file and write a PNG."
        )

        @Argument(help: "Source RAW or JPEG file.") var source: String
        @Argument(help: "Destination PNG.") var destination: String

        func run() throws {
            let src = URL(fileURLWithPath: (source as NSString).expandingTildeInPath)
            let dst = URL(fileURLWithPath: (destination as NSString).expandingTildeInPath)

            let image = try DecodeStage().decode(url: src)
            try PipelineContext.shared.context.writePNGRepresentation(
                of: image,
                to: dst,
                format: .RGBA8,
                colorSpace: ColorSpaces.sRGB
            )
            let w = Int(image.extent.width.rounded())
            let h = Int(image.extent.height.rounded())
            print("Wrote \(dst.path) (\(w)x\(h))")
        }
    }

    struct Thumbnails: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Populate the per-folder thumbnail cache for every ingestible source."
        )

        @Argument(help: "Folder to walk.") var folder: String
        @Flag(name: .long, help: "Regenerate even if a thumbnail already exists.") var force = false

        func run() throws {
            let folderURL = URL(fileURLWithPath: (folder as NSString).expandingTildeInPath)
            let scanner = FolderScanner()
            let cache = ThumbnailCache()
            let items = try scanner.scan(folder: folderURL)

            var generated = 0
            var skipped = 0
            var failed = 0
            for item in items {
                let dest = ThumbnailCache.thumbnailURL(for: item.url)
                if !force, cache.cached(for: item.url) != nil {
                    skipped += 1
                    continue
                }
                do {
                    _ = try cache.generate(for: item.url)
                    generated += 1
                    print("✓ \(item.url.lastPathComponent) -> \(dest.lastPathComponent)")
                } catch {
                    failed += 1
                    FileHandle.standardError.write(
                        Data("✗ \(item.url.lastPathComponent): \(error)\n".utf8)
                    )
                }
            }
            print("---")
            print("\(generated) generated, \(skipped) cached, \(failed) failed (\(items.count) total)")
        }
    }

    struct Render: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Apply a recipe JSON to a source and write the rendered output."
        )

        @Option(name: .long, help: "Path to .pavement.json recipe.") var recipe: String
        @Argument(help: "Source RAW or JPEG.") var source: String
        @Argument(help: "Destination image (PNG or JPG by extension).") var destination: String

        func run() throws {
            let recipeURL = URL(fileURLWithPath: (recipe as NSString).expandingTildeInPath)
            let srcURL = URL(fileURLWithPath: (source as NSString).expandingTildeInPath)
            let dstURL = URL(fileURLWithPath: (destination as NSString).expandingTildeInPath)

            let data = try Data(contentsOf: recipeURL)
            var recipeObj = try EditRecipe.makeDecoder().decode(EditRecipe.self, from: data)
            try Migrations.upgrade(&recipeObj)
            Clamping.clampInPlace(&recipeObj)

            let decoded = try DecodeStage().decode(url: srcURL)
            let rendered = PipelineGraph().apply(recipeObj, to: decoded)

            let ctx = PipelineContext.shared.context
            let ext = dstURL.pathExtension.lowercased()
            switch ext {
            case "jpg", "jpeg":
                try ctx.writeJPEGRepresentation(
                    of: rendered,
                    to: dstURL,
                    colorSpace: ColorSpaces.sRGB,
                    options: [:]
                )
            case "png", "":
                try ctx.writePNGRepresentation(
                    of: rendered,
                    to: dstURL,
                    format: .RGBA8,
                    colorSpace: ColorSpaces.sRGB
                )
            default:
                throw ValidationError("Unsupported destination extension '\(ext)' (use .jpg or .png).")
            }

            let w = Int(rendered.extent.width.rounded())
            let h = Int(rendered.extent.height.rounded())
            print("Wrote \(dstURL.path) (\(w)x\(h))")
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
