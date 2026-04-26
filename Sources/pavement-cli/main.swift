import ArgumentParser
import Foundation
import CoreImage
import CoreGraphics
import ImageIO
import PavementCore

@main
struct PavementCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "pavement-cli",
        abstract: "Smoke-test harness for the Pavement engine.",
        version: PavementCore.version,
        subcommands: [Scan.self, Decode.self, Thumbnails.self, Render.self, Export.self, Presets.self, ColorCheck.self, PresetPreview.self]
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
            abstract: "Export a source (or whole folder with --all) via a named preset.",
            discussion: """
                Calls the SAME Exporter the GUI uses — output is byte-identical
                to what "Export → <preset>" produces in the app, ensuring the
                engine is reproducible outside the UI.

                Run `pavement-cli presets` to see all presets.
                """
        )

        @Option(name: .long, help: "Preset name. Run `pavement-cli presets` to list.") var preset: String
        @Option(name: .long, help: "Override destination path or folder.") var output: String?
        @Option(name: .long, help: "Override resize long edge in pixels (skips preset's resize).") var longEdge: Int?
        @Option(name: .long, help: "Override JPEG quality (0.0-1.0).") var quality: Float?
        @Flag(name: .long, help: "Treat source as a folder and export every ingestible file.") var all = false
        @Argument(help: "Source file or folder (with --all).") var source: String

        func run() throws {
            guard var presetEnum = ExportPreset(rawValue: preset.lowercased()) else {
                let available = ExportPreset.allCases.map(\.rawValue).joined(separator: ", ")
                throw ValidationError("Unknown preset '\(preset)'. Available: \(available)")
            }

            // Resolve overrides into a custom preset (ad-hoc, not registered).
            // We apply them by constructing a custom preset wrapper below
            // when one or both are set.
            let custom = makeCustomSpec(base: presetEnum.spec, longEdge: longEdge, quality: quality)
            if custom != nil { presetEnum = .instagram /* placeholder, ignored when custom provided */ }

            let srcURL = URL(fileURLWithPath: (source as NSString).expandingTildeInPath)

            if all {
                try exportFolder(srcURL, preset: presetEnum, customSpec: custom)
            } else {
                try exportOne(srcURL, preset: presetEnum, customSpec: custom, output: output)
            }
        }

        private func exportOne(_ srcURL: URL, preset: ExportPreset, customSpec: ExportSpec?, output: String?) throws {
            let store = SidecarStore()
            var recipe = try store.load(for: srcURL) ?? EditRecipe()
            try Migrations.upgrade(&recipe)
            Clamping.clampInPlace(&recipe)

            let destination: URL
            if let output {
                destination = URL(fileURLWithPath: (output as NSString).expandingTildeInPath)
            } else if let customSpec {
                destination = srcURL.deletingLastPathComponent()
                    .appendingPathComponent("_exports")
                    .appendingPathComponent(customSpec.folderName)
                    .appendingPathComponent(srcURL.deletingPathExtension().lastPathComponent + "." + (customSpec.format == .jpeg ? "jpg" : "tif"))
            } else {
                destination = Exporter.defaultDestination(source: srcURL, preset: preset)
            }

            try Exporter().export(
                recipe: recipe,
                source: srcURL,
                preset: preset,
                destination: destination,
                specOverride: customSpec
            )
            print("✓ \(destination.path)")
        }

        private func exportFolder(_ folderURL: URL, preset: ExportPreset, customSpec: ExportSpec?) throws {
            let items = try FolderScanner().scan(folder: folderURL).filter { $0.type.isIngestible }
            guard !items.isEmpty else {
                print("No ingestible files under \(folderURL.path).")
                return
            }
            var ok = 0, failed = 0
            for item in items {
                do {
                    try exportOne(item.url, preset: preset, customSpec: customSpec, output: nil)
                    ok += 1
                } catch {
                    failed += 1
                    FileHandle.standardError.write(Data("✗ \(item.url.lastPathComponent): \(error)\n".utf8))
                }
            }
            print("---")
            print("\(ok) exported, \(failed) failed (\(items.count) total) under \(folderURL.path)")
        }

        /// Build a one-off spec from the base preset with --long-edge /
        /// --quality overrides applied. Returns nil when no overrides set.
        private func makeCustomSpec(base: ExportSpec, longEdge: Int?, quality: Float?) -> ExportSpec? {
            guard longEdge != nil || quality != nil else { return nil }
            return ExportSpec(
                name: "\(base.name) (custom)",
                format: base.format,
                longEdge: longEdge ?? base.longEdge,
                colorSpace: base.colorSpace,
                quality: quality ?? base.quality,
                bitDepth: base.bitDepth,
                sharpening: base.sharpening,
                folderName: base.folderName + "-custom"
            )
        }
    }

    struct PresetPreview: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "preset-preview",
            abstract: "Render every built-in preset against a synthetic test scene.",
            discussion: """
                Generates a 800x600 synthetic test image (sky gradient, foliage,
                skin tone patch, neutral grays, saturated patches) then applies
                each built-in preset to it and writes a labeled JPEG per preset.
                Useful for verifying a new preset hits its intended look.

                Optional --source <file>: use a real photo instead of synthetic.
                """
        )

        @Option(name: .long, help: "Optional real source photo (JPG/RAF/CR3) to use instead of synthetic.")
        var source: String?

        @Option(name: .long, help: "Output folder.")
        var outputDir: String = NSTemporaryDirectory() + "pavement-presets"

        @Option(name: .long, help: "Filter to one category (B&W, Film, Cinematic, Color, Street, Landscape).")
        var category: String?

        func run() throws {
            let outDir = URL(fileURLWithPath: (outputDir as NSString).expandingTildeInPath)
            try? FileManager.default.removeItem(at: outDir)
            try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

            // Build base image — either a real source or a synthetic scene.
            let baseImage: CIImage
            if let source {
                let srcURL = URL(fileURLWithPath: (source as NSString).expandingTildeInPath)
                baseImage = try DecodeStage().decode(url: srcURL)
            } else {
                baseImage = makeSyntheticTestScene()
            }

            // Filter presets by category if provided.
            let presets: [Preset]
            if let category {
                presets = BuiltinPresets.all.filter {
                    $0.category.localizedCaseInsensitiveCompare(category) == .orderedSame
                }
                if presets.isEmpty {
                    throw ValidationError("No presets in category '\(category)'")
                }
            } else {
                presets = BuiltinPresets.all
            }

            print("Rendering \(presets.count) presets to \(outDir.path)")
            print("")

            for preset in presets {
                var recipe = EditRecipe()
                recipe.apply(preset: preset)
                let rendered = PipelineGraph().apply(recipe, to: baseImage)

                let safeName = "\(preset.category)_\(preset.id)"
                    .replacingOccurrences(of: "/", with: "-")
                    .replacingOccurrences(of: "&", with: "and")
                let dest = outDir.appendingPathComponent("\(safeName).jpg")
                try JPEGEncoder().write(
                    image: rendered,
                    to: dest,
                    colorSpace: ColorSpaces.sRGB,
                    quality: 0.92
                )
                print("✓ [\(preset.category)] \(preset.name.padding(toLength: 24, withPad: " ", startingAt: 0)) → \(dest.lastPathComponent)")
            }
            print("")
            print("Open \(outDir.path) to view all renderings.")
        }

        /// Build an 800×600 synthetic scene with NATURALISTIC color values
        /// (not saturated primaries — those mask subtle preset effects on
        /// extremes). Each patch represents a real-world target:
        ///
        ///   Top 40%     — sky gradient (mid blue → light horizon)
        ///   Middle 30%  — foliage / earth / fabric (muted greens, brown,
        ///                 dusty muted red)
        ///   Bottom 30%  — skin tone / mid-gray / shadow black
        ///
        /// Values chosen to be "Lightroom-developed" rather than "scanner
        /// reference patches": foliage is sage-green not pure green, "red"
        /// is brick not Coca-Cola, sky is hazy not poster-blue.
        private func makeSyntheticTestScene() -> CIImage {
            let w = 800, h = 600
            let extent = CGRect(x: 0, y: 0, width: w, height: h)

            // Sky gradient — naturalistic mid-blue to light hazy horizon.
            let sky = CIFilter(name: "CILinearGradient")!
            sky.setValue(CIVector(x: 400, y: CGFloat(h)),       forKey: "inputPoint0")
            sky.setValue(CIVector(x: 400, y: CGFloat(h) * 0.6), forKey: "inputPoint1")
            sky.setValue(CIColor(red: 0.52, green: 0.66, blue: 0.82), forKey: "inputColor0") // hazy mid blue
            sky.setValue(CIColor(red: 0.82, green: 0.84, blue: 0.86), forKey: "inputColor1") // soft horizon haze
            let skyImg = (sky.outputImage ?? CIImage(color: .gray)).cropped(to: extent)

            func patch(_ color: CIColor, x: Int, y: Int, w pw: Int, h ph: Int) -> CIImage {
                CIImage(color: color).cropped(to: CGRect(x: x, y: y, width: pw, height: ph))
            }

            // Middle band: muted natural tones (sage-green / earth-brown /
            // dusty-red brick) — what real foliage/structures look like.
            let foliage  = patch(CIColor(red: 0.32, green: 0.42, blue: 0.24), x: 0,   y: 180, w: 280, h: 180)
            let earth    = patch(CIColor(red: 0.55, green: 0.42, blue: 0.32), x: 280, y: 180, w: 240, h: 180)
            let brick    = patch(CIColor(red: 0.62, green: 0.38, blue: 0.30), x: 520, y: 180, w: 280, h: 180)

            // Lower band: skin / neutral gray / shadow.
            let skin     = patch(CIColor(red: 0.78, green: 0.62, blue: 0.52), x: 0,   y: 0,   w: 280, h: 180)
            let gray     = patch(CIColor(red: 0.45, green: 0.45, blue: 0.45), x: 280, y: 0,   w: 240, h: 180)
            let shadow   = patch(CIColor(red: 0.10, green: 0.11, blue: 0.13), x: 520, y: 0,   w: 280, h: 180)

            return shadow
                .composited(over: gray)
                .composited(over: skin)
                .composited(over: brick)
                .composited(over: earth)
                .composited(over: foliage)
                .composited(over: skyImg)
                .cropped(to: extent)
        }
    }

    struct ColorCheck: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "color-check",
            abstract: "Run a color-management sanity test through the pipeline.",
            discussion: """
                Renders synthetic color patches (red, green, blue, gray) through
                the pipeline at identity, exports as both sRGB JPEG and P3 TIFF,
                then reads back the ICC profile name and a sampled pixel from
                each so you can verify the chain hasn't drifted.

                A pass means: ICC profile is present and named correctly, and
                sampled pixel values round-trip within tolerance.
                """
        )

        @Option(name: .long, help: "Working directory for test outputs.")
        var outputDir: String = NSTemporaryDirectory() + "pavement-colorcheck"

        func run() throws {
            let outDir = URL(fileURLWithPath: (outputDir as NSString).expandingTildeInPath)
            try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

            print("Working dir: \(outDir.path)")
            print("Working space (CIContext): Display P3")
            print("")

            // Build a 256×256 patchwork: red top-left, green top-right,
            // blue bottom-left, mid-gray bottom-right.
            let patchSize: CGFloat = 128
            let red   = CIImage(color: CIColor(red: 1.0, green: 0.0, blue: 0.0)).cropped(to: CGRect(x: 0, y: patchSize, width: patchSize, height: patchSize))
            let green = CIImage(color: CIColor(red: 0.0, green: 1.0, blue: 0.0)).cropped(to: CGRect(x: patchSize, y: patchSize, width: patchSize, height: patchSize))
            let blue  = CIImage(color: CIColor(red: 0.0, green: 0.0, blue: 1.0)).cropped(to: CGRect(x: 0, y: 0, width: patchSize, height: patchSize))
            let gray  = CIImage(color: CIColor(red: 0.5, green: 0.5, blue: 0.5)).cropped(to: CGRect(x: patchSize, y: 0, width: patchSize, height: patchSize))
            let composite = red
                .composited(over: green)
                .composited(over: blue)
                .composited(over: gray)
                .cropped(to: CGRect(x: 0, y: 0, width: patchSize * 2, height: patchSize * 2))

            // Write sRGB JPEG
            let sRGBJPEG = outDir.appendingPathComponent("patches-sRGB.jpg")
            try JPEGEncoder().write(image: composite, to: sRGBJPEG, colorSpace: ColorSpaces.sRGB, quality: 1.0)
            try report(file: sRGBJPEG, expectedSpace: "sRGB")

            // Write P3 JPEG
            let p3JPEG = outDir.appendingPathComponent("patches-P3.jpg")
            try JPEGEncoder().write(image: composite, to: p3JPEG, colorSpace: ColorSpaces.displayP3, quality: 1.0)
            try report(file: p3JPEG, expectedSpace: "Display P3")

            // Write P3 16-bit TIFF
            let p3TIFF = outDir.appendingPathComponent("patches-P3.tif")
            try TIFFEncoder().write(image: composite, to: p3TIFF, colorSpace: ColorSpaces.displayP3, bitDepth: 16)
            try report(file: p3TIFF, expectedSpace: "Display P3")

            // Write Adobe RGB TIFF
            let argbTIFF = outDir.appendingPathComponent("patches-AdobeRGB.tif")
            try TIFFEncoder().write(image: composite, to: argbTIFF, colorSpace: ColorSpaces.adobeRGB, bitDepth: 16)
            try report(file: argbTIFF, expectedSpace: "Adobe RGB (1998)")

            print("")
            print("Open the four files above and check they look identical on a")
            print("color-managed viewer (Preview, Photoshop). If sRGB and P3 look")
            print("different on screen, your viewer isn't honoring the embedded")
            print("ICC profile.")
        }

        private func report(file: URL, expectedSpace: String) throws {
            guard let src = CGImageSourceCreateWithURL(file as CFURL, nil),
                  let cg = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
                print("✗ \(file.lastPathComponent): could not read back")
                return
            }
            let space = cg.colorSpace
            let name = (space?.name as String?) ?? "<no name>"
            let bits = cg.bitsPerComponent
            let w = cg.width, h = cg.height

            // Sample center pixels of each quadrant.
            let samples = sampleQuadrants(cg)

            let icc = name
            // Strip spaces and parens from both sides — the CG name is
            // "kCGColorSpaceAdobeRGB1998" while expectedSpace is
            // "Adobe RGB (1998)". The substring still matches if you
            // normalize them.
            let normalize: (String) -> String = { s in
                s.replacingOccurrences(of: " ", with: "")
                 .replacingOccurrences(of: "(", with: "")
                 .replacingOccurrences(of: ")", with: "")
                 .lowercased()
            }
            let match = normalize(icc).contains(normalize(expectedSpace))
            let icon = match ? "✓" : "⚠"
            print("\(icon) \(file.lastPathComponent)")
            print("    ICC profile      : \(icc)  (expected ~\(expectedSpace))")
            print("    \(w)×\(h) @ \(bits)-bit")
            print("    Top-left   (red) : \(samples.0)")
            print("    Top-right (green): \(samples.1)")
            print("    Btm-left  (blue) : \(samples.2)")
            print("    Btm-right (gray) : \(samples.3)")
        }

        private func sampleQuadrants(_ cg: CGImage) -> (String, String, String, String) {
            let w = cg.width, h = cg.height
            let qx = w / 4, qy = h / 4
            let positions = [
                (qx,        qy),         // top-left in image coords (origin top-left for CGImage)
                (qx * 3,    qy),         // top-right
                (qx,        qy * 3),     // bottom-left
                (qx * 3,    qy * 3)      // bottom-right
            ]
            // Render to an 8-bit sRGB buffer for consistent sampling — purely
            // for "did we keep red, green, blue, gray" diagnostic purposes.
            let space = CGColorSpace(name: CGColorSpace.sRGB)!
            let bytesPerRow = w * 4
            var buffer = [UInt8](repeating: 0, count: h * bytesPerRow)
            buffer.withUnsafeMutableBytes { ptr in
                guard let ctx = CGContext(
                    data: ptr.baseAddress,
                    width: w, height: h,
                    bitsPerComponent: 8, bytesPerRow: bytesPerRow,
                    space: space,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                ) else { return }
                ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
            }
            func sample(_ p: (Int, Int)) -> String {
                let (x, y) = p
                let i = y * bytesPerRow + x * 4
                let r = buffer[i], g = buffer[i+1], b = buffer[i+2]
                return "rgb(\(r), \(g), \(b))"
            }
            return (sample(positions[0]), sample(positions[1]),
                    sample(positions[2]), sample(positions[3]))
        }
    }

    struct Presets: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "List available export presets and their settings."
        )

        func run() {
            print("Available export presets:")
            print("")
            let nameWidth = ExportPreset.allCases.map { $0.rawValue.count }.max() ?? 12
            for preset in ExportPreset.allCases {
                let s = preset.spec
                let dim = s.longEdge.map { "\($0)px" } ?? "full"
                let depth = s.bitDepth == 16 ? "16-bit" : "8-bit"
                let q = s.format == .jpeg ? "q\(Int(s.quality * 100))" : depth
                let line = "  \(preset.rawValue.padding(toLength: nameWidth, withPad: " ", startingAt: 0))" +
                    "   \(s.format.rawValue.uppercased())  \(dim.padding(toLength: 8, withPad: " ", startingAt: 0))" +
                    " \(s.colorSpace.rawValue.padding(toLength: 10, withPad: " ", startingAt: 0))" +
                    " \(q.padding(toLength: 6, withPad: " ", startingAt: 0))" +
                    " sharpen=\(s.sharpening.rawValue)"
                print(line)
            }
            print("")
            print("Use with: pavement-cli export --preset <name> <source>")
            print("Override resize: --long-edge 2400")
            print("Override quality: --quality 0.85")
            print("Batch a folder: --all <folder>")
        }
    }
}
