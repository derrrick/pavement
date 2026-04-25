import XCTest
import CoreImage
@testable import PavementCore

final class MatchLookTests: XCTestCase {
    private func solid(red: CGFloat, green: CGFloat, blue: CGFloat, size: CGFloat = 64) -> CIImage {
        CIImage(color: CIColor(red: red, green: green, blue: blue))
            .cropped(to: CGRect(x: 0, y: 0, width: size, height: size))
    }

    func testStatisticsForGrayImageHaveZeroChroma() {
        let stats = ImageStatisticsCalculator.compute(from: solid(red: 0.5, green: 0.5, blue: 0.5))
        XCTAssertEqual(stats.meanA, 0, accuracy: 1)
        XCTAssertEqual(stats.meanB, 0, accuracy: 1)
        XCTAssertLessThan(stats.chromaMagnitude, 1)
    }

    func testStatisticsForRedImageHavePositiveA() {
        let stats = ImageStatisticsCalculator.compute(from: solid(red: 0.85, green: 0.1, blue: 0.1))
        XCTAssertGreaterThan(stats.meanA, 30, "Red should give positive a*")
        XCTAssertGreaterThan(stats.chromaMagnitude, 30)
    }

    func testStatisticsForBlueImageHaveNegativeB() {
        let stats = ImageStatisticsCalculator.compute(from: solid(red: 0.1, green: 0.1, blue: 0.85))
        XCTAssertLessThan(stats.meanB, -30, "Blue should give negative b*")
    }

    func testMatchPullsCurrentExposureUpToReference() {
        let dark = ImageStatisticsCalculator.compute(from: solid(red: 0.2, green: 0.2, blue: 0.2))
        let bright = ImageStatisticsCalculator.compute(from: solid(red: 0.7, green: 0.7, blue: 0.7))
        let ops = MatchLook.deriveOperations(from: bright, current: dark)
        XCTAssertGreaterThan(ops.exposure.ev, 0.5, "Should boost exposure to match brighter reference")
    }

    func testMatchPullsCurrentSaturationUpToReference() {
        let muted = ImageStatisticsCalculator.compute(from: solid(red: 0.5, green: 0.45, blue: 0.4))
        let saturated = ImageStatisticsCalculator.compute(from: solid(red: 0.85, green: 0.2, blue: 0.2))
        let ops = MatchLook.deriveOperations(from: saturated, current: muted)
        XCTAssertGreaterThan(ops.color.saturation, 10)
    }

    func testZeroIntensityProducesIdentity() {
        let a = ImageStatisticsCalculator.compute(from: solid(red: 0.2, green: 0.2, blue: 0.2))
        let b = ImageStatisticsCalculator.compute(from: solid(red: 0.85, green: 0.2, blue: 0.2))
        let ops = MatchLook.deriveOperations(from: b, current: a, intensity: 0)
        XCTAssertEqual(ops.exposure.ev, 0)
        XCTAssertEqual(ops.tone.contrast, 0)
        XCTAssertEqual(ops.color.saturation, 0)
    }

    func testIdentityWhenStatsAreEqual() {
        let stats = ImageStatisticsCalculator.compute(from: solid(red: 0.5, green: 0.5, blue: 0.5))
        let ops = MatchLook.deriveOperations(from: stats, current: stats)
        XCTAssertEqual(ops.exposure.ev, 0, accuracy: 0.01)
        XCTAssertEqual(ops.tone.contrast, 0)
        XCTAssertEqual(ops.color.saturation, 0)
    }
}
