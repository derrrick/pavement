import XCTest
import CoreImage
@testable import PavementCore

final class PipelineContextTests: XCTestCase {
    func testWorkingColorSpaceIsDisplayP3() {
        let ctx = PipelineContext().context
        let p3 = ColorSpaces.displayP3
        let working = ctx.workingColorSpace
        XCTAssertNotNil(working)
        XCTAssertEqual(working?.name, p3.name)
    }

    func testRenderTinyCIImageRoundTrip() throws {
        let pc = PipelineContext()
        // Solid 4x4 red image, sRGB-tagged input.
        let red = CIImage(color: .red).cropped(to: CGRect(x: 0, y: 0, width: 4, height: 4))
        let cg = pc.context.createCGImage(red, from: red.extent)
        XCTAssertNotNil(cg)
        XCTAssertEqual(cg?.width, 4)
        XCTAssertEqual(cg?.height, 4)
    }
}
