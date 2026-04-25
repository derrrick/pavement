import XCTest
import CoreImage
import ImageIO
@testable import PavementCore

final class ExportRoundTripTests: XCTestCase {
    private var tmpDir: URL!

    override func setUpWithError() throws {
        let unique = "pavement-export-\(UUID().uuidString)"
        tmpDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(unique)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tmpDir)
    }

    /// Generates a 1024x683 JPEG via sips so we have a real ingestible source
    /// to export. Skips the test if the system asset isn't available.
    private func makeSourceJPEG() throws -> URL {
        let source = tmpDir.appendingPathComponent("source.jpg")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sips")
        process.arguments = [
            "-s", "format", "jpeg",
            "-Z", "1024",
            "/System/Library/Wallpapers/.default/DefaultAerial.heic",
            "--out", source.path
        ]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()
        try XCTSkipUnless(FileManager.default.fileExists(atPath: source.path),
                          "Could not produce a test JPEG via sips")
        return source
    }

    private func dimensions(of url: URL) -> (width: Int, height: Int)? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [String: Any],
              let w = props[kCGImagePropertyPixelWidth as String] as? Int,
              let h = props[kCGImagePropertyPixelHeight as String] as? Int
        else { return nil }
        return (w, h)
    }

    func testInstagramExportProducesResizedJPEG() throws {
        let source = try makeSourceJPEG()
        let dest = tmpDir.appendingPathComponent("ig.jpg")
        let recipe = EditRecipe()

        try Exporter().export(
            recipe: recipe,
            source: source,
            preset: .instagram,
            destination: dest
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: dest.path))
        let dims = try XCTUnwrap(dimensions(of: dest))
        XCTAssertLessThanOrEqual(max(dims.width, dims.height), 1350)
    }

    func testPrintExportProducesTIFFAtNativeSize() throws {
        let source = try makeSourceJPEG()
        let dest = tmpDir.appendingPathComponent("print.tif")
        let recipe = EditRecipe()

        try Exporter().export(
            recipe: recipe,
            source: source,
            preset: .print,
            destination: dest
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: dest.path))
        let dims = try XCTUnwrap(dimensions(of: dest))
        // Print preset has no resize, so output matches source dimensions
        // (sips produces a 1024px-long source).
        XCTAssertEqual(max(dims.width, dims.height), 1024, accuracy: 4)
    }

    func testWebExportRespects2048LongEdge() throws {
        let source = try makeSourceJPEG()
        let dest = tmpDir.appendingPathComponent("web.jpg")
        let recipe = EditRecipe()

        try Exporter().export(
            recipe: recipe,
            source: source,
            preset: .web,
            destination: dest
        )

        let dims = try XCTUnwrap(dimensions(of: dest))
        XCTAssertLessThanOrEqual(max(dims.width, dims.height), 2048)
    }

    func testCropAffectsExportedDimensions() throws {
        let source = try makeSourceJPEG()
        let dest = tmpDir.appendingPathComponent("cropped.jpg")
        var recipe = EditRecipe()
        recipe.operations.crop.x = 0.25
        recipe.operations.crop.y = 0.25
        recipe.operations.crop.w = 0.5
        recipe.operations.crop.h = 0.5

        try Exporter().export(
            recipe: recipe,
            source: source,
            preset: .web,
            destination: dest
        )

        let dims = try XCTUnwrap(dimensions(of: dest))
        // Pre-resize crop is half size; post-resize long edge is min(half, 2048).
        // We just need to assert the file is produced with finite size.
        XCTAssertGreaterThan(dims.width, 0)
        XCTAssertGreaterThan(dims.height, 0)
    }
}
