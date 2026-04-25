import XCTest
@testable import PavementCore

final class RAWFileTypeTests: XCTestCase {
    func testExtensionMapping() {
        XCTAssertEqual(RAWFileType.from(url: URL(fileURLWithPath: "/x/DSCF1234.RAF")), .raf)
        XCTAssertEqual(RAWFileType.from(url: URL(fileURLWithPath: "/x/DSCF1234.raf")), .raf)
        XCTAssertEqual(RAWFileType.from(url: URL(fileURLWithPath: "/x/IMG_0001.CR3")), .cr3)
        XCTAssertEqual(RAWFileType.from(url: URL(fileURLWithPath: "/x/foo.dng")), .dng)
        XCTAssertEqual(RAWFileType.from(url: URL(fileURLWithPath: "/x/foo.JPG")), .jpeg)
        XCTAssertEqual(RAWFileType.from(url: URL(fileURLWithPath: "/x/foo.jpeg")), .jpeg)
        XCTAssertEqual(RAWFileType.from(url: URL(fileURLWithPath: "/x/foo.tif")), .unknown)
        XCTAssertEqual(RAWFileType.from(url: URL(fileURLWithPath: "/x/no_extension")), .unknown)
    }

    func testIsRawFlag() {
        XCTAssertTrue(RAWFileType.raf.isRaw)
        XCTAssertTrue(RAWFileType.cr3.isRaw)
        XCTAssertTrue(RAWFileType.dng.isRaw)
        XCTAssertFalse(RAWFileType.jpeg.isRaw)
        XCTAssertFalse(RAWFileType.unknown.isRaw)
    }

    func testIsIngestibleFlag() {
        XCTAssertTrue(RAWFileType.raf.isIngestible)
        XCTAssertTrue(RAWFileType.jpeg.isIngestible)
        XCTAssertFalse(RAWFileType.unknown.isIngestible)
    }
}
