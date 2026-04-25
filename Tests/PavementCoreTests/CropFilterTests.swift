import XCTest
import CoreImage
@testable import PavementCore

final class CropFilterTests: XCTestCase {
    private func solid(width: CGFloat, height: CGFloat) -> CIImage {
        CIImage(color: .red).cropped(to: CGRect(x: 0, y: 0, width: width, height: height))
    }

    func testIdentityCropReturnsFullExtent() {
        let input = solid(width: 100, height: 80)
        let output = CropFilter().apply(image: input, op: CropOp())
        XCTAssertEqual(output.extent, input.extent)
    }

    func testDisabledCropReturnsInput() {
        var op = CropOp()
        op.enabled = false
        op.x = 0.25; op.w = 0.5
        let input = solid(width: 100, height: 80)
        let output = CropFilter().apply(image: input, op: op)
        XCTAssertEqual(output.extent, input.extent)
    }

    func testNarrowCropReducesExtent() {
        var op = CropOp()
        op.x = 0.25; op.y = 0.25; op.w = 0.5; op.h = 0.5
        let input = solid(width: 100, height: 80)
        let output = CropFilter().apply(image: input, op: op)
        XCTAssertEqual(output.extent.width, 50, accuracy: 0.5)
        XCTAssertEqual(output.extent.height, 40, accuracy: 0.5)
    }

    func testCropRectMathTopLeftOrigin() {
        let extent = CGRect(x: 0, y: 0, width: 100, height: 100)
        var op = CropOp()
        op.x = 0.0; op.y = 0.0; op.w = 0.5; op.h = 0.5
        // PLAN.md uses top-left origin: (0,0) of recipe = top-left of image,
        // so this rect occupies the TOP-LEFT quadrant. In CIImage's
        // bottom-left coord system, that's y = 50..100.
        let rect = CropFilter.cropRectInImage(extent: extent, op: op)
        XCTAssertEqual(rect, CGRect(x: 0, y: 50, width: 50, height: 50))
    }

    func testAspectRatioLookup() {
        XCTAssertEqual(CropFilter.aspectRatio("1:1"), 1)
        XCTAssertEqual(CropFilter.aspectRatio("3:2"), 1.5)
        XCTAssertEqual(CropFilter.aspectRatio("4:5"), 0.8)
        XCTAssertEqual(CropFilter.aspectRatio("16:9"), 16.0/9.0)
        XCTAssertNil(CropFilter.aspectRatio("free"))
        XCTAssertNil(CropFilter.aspectRatio("garbage"))
    }
}
