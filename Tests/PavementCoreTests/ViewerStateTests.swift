import XCTest
@testable import PavementUI

final class ViewerStateTests: XCTestCase {
    func testFitScaleChoosesConstrainingDimension() {
        let scale = ViewerState.fitScale(
            imageSize: CGSize(width: 4000, height: 2000),
            viewport: CGSize(width: 1000, height: 800)
        )

        XCTAssertEqual(scale, 0.25, accuracy: 0.001)
    }

    func testActualSizeSetsOneToOneScale() {
        var state = ViewerState()
        state.updateImage(
            extent: CGRect(x: 0, y: 0, width: 2000, height: 1000),
            viewport: CGSize(width: 1000, height: 500)
        )

        state.actualSize()

        XCTAssertEqual(state.zoomMode, .actualSize)
        XCTAssertEqual(state.scale, 1, accuracy: 0.001)
    }

    func testCursorCenteredZoomPreservesAnchorImagePoint() {
        var state = ViewerState()
        state.updateImage(
            extent: CGRect(x: 0, y: 0, width: 1000, height: 1000),
            viewport: CGSize(width: 500, height: 500)
        )
        let anchor = CGPoint(x: 375, y: 250)
        let before = imagePoint(at: anchor, in: state)

        state.zoom(by: 2, anchor: anchor)

        let after = imagePoint(at: anchor, in: state)
        XCTAssertEqual(before.x, after.x, accuracy: 0.001)
        XCTAssertEqual(before.y, after.y, accuracy: 0.001)
        XCTAssertEqual(state.zoomMode, .custom)
    }

    func testPanClampsWhenZoomed() {
        var state = ViewerState()
        state.updateImage(
            extent: CGRect(x: 0, y: 0, width: 1000, height: 1000),
            viewport: CGSize(width: 500, height: 500)
        )
        state.actualSize()

        state.pan(by: CGSize(width: 1_000, height: -1_000))

        XCTAssertEqual(state.panOffset.width, 250, accuracy: 0.001)
        XCTAssertEqual(state.panOffset.height, -250, accuracy: 0.001)
    }

    private func imagePoint(at anchor: CGPoint, in state: ViewerState) -> CGPoint {
        let center = CGPoint(x: state.viewportSize.width / 2, y: state.viewportSize.height / 2)
        return CGPoint(
            x: (anchor.x - center.x - state.panOffset.width) / state.scale,
            y: (anchor.y - center.y - state.panOffset.height) / state.scale
        )
    }
}
