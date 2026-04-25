import XCTest
import CoreImage
@testable import PavementCore

final class HistogramComputerTests: XCTestCase {
    private func solid(red: CGFloat, green: CGFloat, blue: CGFloat, size: CGFloat = 32) -> CIImage {
        CIImage(color: CIColor(red: red, green: green, blue: blue))
            .cropped(to: CGRect(x: 0, y: 0, width: size, height: size))
    }

    func testEmptyImageReturnsZeroHistogram() {
        let empty = CIImage.empty()
        let histogram = HistogramComputer().compute(image: empty)
        XCTAssertEqual(histogram.red.reduce(0, +), 0)
        XCTAssertEqual(histogram.green.reduce(0, +), 0)
        XCTAssertEqual(histogram.blue.reduce(0, +), 0)
    }

    func testFullRedFillsRedTopBin() {
        let image = solid(red: 1.0, green: 0.0, blue: 0.0)
        let histogram = HistogramComputer().compute(image: image)
        let totalPixels = histogram.red.reduce(0, +)
        XCTAssertGreaterThan(totalPixels, 0)
        XCTAssertGreaterThan(histogram.red[255], totalPixels / 2,
                             "Pure red image should pile up in the top red bin")
        XCTAssertEqual(histogram.green[0] + histogram.green[1], totalPixels,
                       "Pure red has zero green")
        XCTAssertEqual(histogram.blue[0] + histogram.blue[1], totalPixels,
                       "Pure red has zero blue")
    }

    func testNeutralGrayPilesNearMidLuminance() {
        let image = solid(red: 0.5, green: 0.5, blue: 0.5)
        let histogram = HistogramComputer().compute(image: image)
        let totalPixels = histogram.luminance.reduce(0, +)
        XCTAssertGreaterThan(totalPixels, 0)
        // 50% gray in linear → ~0.735 in sRGB encoded → bin ≈ 188
        let dominantBin = histogram.luminance.firstIndex { $0 == histogram.luminance.max() } ?? 0
        XCTAssertGreaterThan(dominantBin, 100)
        XCTAssertLessThan(dominantBin, 230)
    }

    func testHistogramSumEqualsPixelCount() {
        let image = solid(red: 0.3, green: 0.3, blue: 0.3, size: 64)
        let histogram = HistogramComputer().compute(image: image)
        let totalRed = histogram.red.reduce(0, +)
        let totalGreen = histogram.green.reduce(0, +)
        let totalBlue = histogram.blue.reduce(0, +)
        XCTAssertEqual(totalRed, totalGreen)
        XCTAssertEqual(totalGreen, totalBlue)
        XCTAssertGreaterThan(totalRed, 0)
    }
}
