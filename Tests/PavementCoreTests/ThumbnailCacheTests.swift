import XCTest
@testable import PavementCore

final class ThumbnailCacheTests: XCTestCase {
    private var tmpDir: URL!

    override func setUpWithError() throws {
        let unique = "pavement-thumb-\(UUID().uuidString)"
        tmpDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(unique)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tmpDir)
    }

    func testThumbnailURLIncludesOriginalExtension() {
        let raf = URL(fileURLWithPath: "/photos/DSCF1234.RAF")
        let cr3 = URL(fileURLWithPath: "/photos/DSCF1234.CR3")
        let rafThumb = ThumbnailCache.thumbnailURL(for: raf)
        let cr3Thumb = ThumbnailCache.thumbnailURL(for: cr3)

        XCTAssertEqual(rafThumb.lastPathComponent, "DSCF1234.raf.jpg")
        XCTAssertEqual(cr3Thumb.lastPathComponent, "DSCF1234.cr3.jpg")
        XCTAssertNotEqual(rafThumb, cr3Thumb)
        XCTAssertEqual(rafThumb.deletingLastPathComponent().lastPathComponent, "thumbnails")
    }

    func testThumbnailURLLivesUnderPavementSubdir() {
        let url = ThumbnailCache.thumbnailURL(for: URL(fileURLWithPath: "/photos/A.RAF"))
        XCTAssertTrue(url.path.contains("/_pavement/thumbnails/"))
    }

    func testCachedReturnsNilWhenAbsent() throws {
        let source = tmpDir.appendingPathComponent("DSCF.RAF")
        try Data("raw".utf8).write(to: source)
        XCTAssertNil(ThumbnailCache().cached(for: source))
    }

    func testGenerateProducesScaledJpegFromJpegSource() throws {
        // Use sips to make a real 1024x683 JPEG so we exercise the actual
        // CIImage(contentsOf:) -> JPEG round-trip path.
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
                          "Could not produce a test JPEG via sips on this machine")

        let cache = ThumbnailCache()
        let dest = try cache.generate(for: source)
        XCTAssertTrue(FileManager.default.fileExists(atPath: dest.path))

        // Validate dimensions: long edge should be <= 512.
        guard let imageSource = CGImageSourceCreateWithURL(dest as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any],
              let width = props[kCGImagePropertyPixelWidth as String] as? Int,
              let height = props[kCGImagePropertyPixelHeight as String] as? Int
        else {
            return XCTFail("Could not read thumbnail dimensions")
        }
        XCTAssertLessThanOrEqual(max(width, height), 512)
        XCTAssertGreaterThan(min(width, height), 0)
    }

    func testEnsureReusesCached() throws {
        let source = tmpDir.appendingPathComponent("DSCF.RAF")
        try Data("dummy".utf8).write(to: source)
        let dest = ThumbnailCache.thumbnailURL(for: source)
        try FileManager.default.createDirectory(
            at: dest.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data([0xFF, 0xD8, 0xFF, 0xD9]).write(to: dest) // valid-looking JPEG marker bytes

        let cache = ThumbnailCache()
        let returned = try cache.ensure(for: source)
        XCTAssertEqual(returned.path, dest.path)
    }
}
