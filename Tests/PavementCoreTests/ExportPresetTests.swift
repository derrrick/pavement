import XCTest
@testable import PavementCore

final class ExportPresetTests: XCTestCase {
    func testInstagramSpec() {
        let spec = ExportPreset.instagram.spec
        XCTAssertEqual(spec.name, "Instagram (Portrait)")
        XCTAssertEqual(spec.format, .jpeg)
        XCTAssertEqual(spec.longEdge, 1350)
        XCTAssertEqual(spec.colorSpace, .sRGB)
        XCTAssertEqual(spec.quality, 0.9, accuracy: 0.001)
        XCTAssertEqual(spec.bitDepth, 8)
        XCTAssertEqual(spec.sharpening, .screen)
        XCTAssertEqual(spec.folderName, "instagram")
    }

    func testWebSpec() {
        let spec = ExportPreset.web.spec
        XCTAssertEqual(spec.format, .jpeg)
        XCTAssertEqual(spec.longEdge, 2048)
        XCTAssertEqual(spec.quality, 0.85, accuracy: 0.001)
    }

    func testPrintSpecIsTiff16P3() {
        let spec = ExportPreset.print.spec
        XCTAssertEqual(spec.format, .tiff)
        XCTAssertNil(spec.longEdge)
        XCTAssertEqual(spec.colorSpace, .displayP3)
        XCTAssertEqual(spec.bitDepth, 16)
        XCTAssertEqual(spec.sharpening, .print)
    }

    func testDefaultDestinationLayout() {
        let source = URL(fileURLWithPath: "/photos/2026-04/DSCF1234.RAF")
        let dest = Exporter.defaultDestination(source: source, preset: .instagram)
        XCTAssertEqual(dest.lastPathComponent, "DSCF1234.jpg")
        XCTAssertEqual(dest.deletingLastPathComponent().lastPathComponent, "instagram")
        XCTAssertEqual(dest.deletingLastPathComponent().deletingLastPathComponent().lastPathComponent, "_exports")
    }

    func testDefaultDestinationTIFFExtension() {
        let dest = Exporter.defaultDestination(
            source: URL(fileURLWithPath: "/photos/foo.CR3"),
            preset: .print
        )
        XCTAssertEqual(dest.pathExtension, "tif")
    }
}
