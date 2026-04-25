import XCTest
@testable import PavementCore

final class ToneCurveInterpolatorTests: XCTestCase {
    func testIdentityCurveProducesIdentityLUT() {
        let lut = ToneCurveInterpolator.sample(controlPoints: [[0, 0], [1, 1]], samples: 256)
        XCTAssertEqual(lut.count, 256)
        for i in 0..<256 {
            let expected = Float(i) / 255.0
            XCTAssertEqual(lut[i], expected, accuracy: 0.005)
        }
    }

    func testEndpointsAreExact() {
        let lut = ToneCurveInterpolator.sample(controlPoints: [[0, 0], [1, 1]], samples: 100)
        XCTAssertEqual(lut.first ?? -1, 0, accuracy: 0.005)
        XCTAssertEqual(lut.last ?? -1, 1, accuracy: 0.005)
    }

    func testSCurveIsMonotonicAndSymmetric() {
        let lut = ToneCurveInterpolator.sample(
            controlPoints: [[0, 0], [0.25, 0.18], [0.75, 0.82], [1, 1]],
            samples: 256
        )
        // Monotonic non-decreasing
        for i in 1..<lut.count {
            XCTAssertGreaterThanOrEqual(lut[i], lut[i - 1] - 0.005)
        }
        // Approximately symmetric around (0.5, 0.5)
        XCTAssertEqual(lut[127], 0.5, accuracy: 0.04)
        XCTAssertEqual(lut[63] + lut[191], 1.0, accuracy: 0.04)
    }

    func testSCurveLowersShadowsAndLiftsHighlights() {
        let lut = ToneCurveInterpolator.sample(
            controlPoints: [[0, 0], [0.25, 0.18], [0.75, 0.82], [1, 1]],
            samples: 256
        )
        XCTAssertLessThan(lut[63], 0.25)   // shadows pulled down at x=0.25
        XCTAssertGreaterThan(lut[191], 0.75) // highlights lifted at x=0.75
    }

    func testTwoPointDiagonalIsLinearIdentity() {
        let lut = ToneCurveInterpolator.sample(controlPoints: [[0, 0], [1, 1]], samples: 1024)
        for i in 0..<lut.count {
            let expected = Float(i) / 1023.0
            XCTAssertEqual(lut[i], expected, accuracy: 1.0 / 1024.0)
        }
    }

    func testSinglePointReturnsConstant() {
        let lut = ToneCurveInterpolator.sample(controlPoints: [[0.5, 0.7]], samples: 16)
        for value in lut {
            XCTAssertEqual(value, 0.7, accuracy: 0.001)
        }
    }

    func testEmptyControlPointsReturnIdentity() {
        let lut = ToneCurveInterpolator.sample(controlPoints: [], samples: 16)
        XCTAssertEqual(lut[0], 0, accuracy: 0.005)
        XCTAssertEqual(lut[15], 1, accuracy: 0.005)
    }

    func testOutputClampedToZeroOne() {
        let lut = ToneCurveInterpolator.sample(
            controlPoints: [[0, 0], [0.5, 1.5], [1, -0.5]],
            samples: 64
        )
        for value in lut {
            XCTAssertGreaterThanOrEqual(value, 0)
            XCTAssertLessThanOrEqual(value, 1)
        }
    }
}
