import XCTest
import CoreImage
@testable import PavementCore

final class HSLFilterTests: XCTestCase {
    private func sample(_ image: CIImage, ctx: CIContext = PipelineContext.shared.context) -> [Float] {
        var out = [UInt8](repeating: 0, count: 4)
        ctx.render(
            image,
            toBitmap: &out,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: ColorSpaces.sRGB
        )
        return out.map { Float($0) / 255.0 }
    }

    private func solid(red: Float, green: Float, blue: Float) -> CIImage {
        CIImage(color: CIColor(red: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue)))
            .cropped(to: CGRect(x: 0, y: 0, width: 4, height: 4))
    }

    func testIdentityOpIsByteIdentity() {
        XCTAssertTrue(HSLFilter.isIdentity(HSLOp()))
    }

    func testNonZeroBandIsNotIdentity() {
        var op = HSLOp()
        op.red.s = 1
        XCTAssertFalse(HSLFilter.isIdentity(op))
    }

    func testIdentityOpReturnsInputUnchanged() {
        let input = solid(red: 0.7, green: 0.2, blue: 0.2)
        let output = HSLFilter().apply(image: input, op: HSLOp())
        let inSample = sample(input)
        let outSample = sample(output)
        for (i, o) in zip(inSample, outSample) {
            XCTAssertEqual(i, o, accuracy: 0.005)
        }
    }

    func testRedSaturationNegativeDesaturatesRed() {
        var op = HSLOp()
        op.red.s = -100
        let input = solid(red: 0.8, green: 0.1, blue: 0.1)
        let output = HSLFilter().apply(image: input, op: op)
        let s = sample(output)
        XCTAssertGreaterThan(s[1], 0.15, "Desaturating red should pull G/B closer to R")
        XCTAssertGreaterThan(s[2], 0.15)
    }

    func testRedSaturationPositiveSaturatesRed() {
        var op = HSLOp()
        op.red.s = 100
        let input = solid(red: 0.6, green: 0.3, blue: 0.3)
        let output = HSLFilter().apply(image: input, op: op)
        let s = sample(output)
        XCTAssertLessThan(s[1], 0.3, "Saturating red should push G/B away from R")
    }

    func testBlueLuminanceShiftAffectsBlue() {
        var op = HSLOp()
        op.blue.l = 80
        let input = solid(red: 0.1, green: 0.1, blue: 0.6)
        let output = HSLFilter().apply(image: input, op: op)
        let s = sample(output)
        XCTAssertGreaterThan(s[2], 0.6, "Increasing blue luminance should brighten blue channel")
    }

    func testNeutralGrayBarelyChanges() {
        // Gray pixels have undefined hue and ~zero saturation; HSL should
        // leave them essentially untouched. Trilinear interpolation through
        // the 16³ LUT bleeds a small amount from neighboring cells, so we
        // allow a generous tolerance and only require the deviation to be
        // far smaller than what a saturated red pixel would see.
        var op = HSLOp()
        op.red.h = 100; op.red.s = 100; op.red.l = 100
        let input = solid(red: 0.5, green: 0.5, blue: 0.5)
        let output = HSLFilter().apply(image: input, op: op)
        let inS = sample(input)
        let outS = sample(output)
        for (i, o) in zip(inS, outS) {
            XCTAssertEqual(i, o, accuracy: 0.1)
        }
    }

    func testLUTIs16Cubed() {
        let lut = HSLFilter.makeLUT(op: HSLOp(), dimension: 16)
        XCTAssertEqual(lut.dimension, 16)
        XCTAssertEqual(lut.data.count, 16 * 16 * 16 * 4 * MemoryLayout<Float>.size)
    }

    /// Regression: with the previous HSV-based math, desaturating pure blue
    /// (0, 0, 1) collapsed it to white (1, 1, 1) because V stayed at max.
    /// True HSL gives mid-gray, which is what users expect.
    func testDesaturatingPureBlueProducesGrayNotWhite() {
        var op = HSLOp()
        op.blue.s = -100
        let input = solid(red: 0, green: 0, blue: 1)
        let output = HSLFilter().apply(image: input, op: op)
        let s = sample(output)
        // Expect roughly mid-gray, not white. sRGB-encoded ~0.5 linear is
        // around 0.74 byte-encoded, so accept anything mid-range.
        XCTAssertLessThan(s[0], 0.95, "Should not be white")
        XCTAssertEqual(s[0], s[1], accuracy: 0.05, "R/G should match (gray)")
        XCTAssertEqual(s[1], s[2], accuracy: 0.05, "G/B should match (gray)")
    }

    func testRgbToHslMatchesKnownConversions() {
        var hsl = HSLFilter.rgbToHsl(0, 0, 1)
        XCTAssertEqual(hsl.0, 240, accuracy: 0.5)
        XCTAssertEqual(hsl.1, 1, accuracy: 0.005)
        XCTAssertEqual(hsl.2, 0.5, accuracy: 0.005)

        hsl = HSLFilter.rgbToHsl(1, 1, 1)
        XCTAssertEqual(hsl.1, 0, accuracy: 0.005)
        XCTAssertEqual(hsl.2, 1, accuracy: 0.005)

        hsl = HSLFilter.rgbToHsl(1, 0, 0)
        XCTAssertEqual(hsl.0, 0, accuracy: 0.5)
        XCTAssertEqual(hsl.2, 0.5, accuracy: 0.005)
    }

    func testHslToRgbRoundTripsKnownColors() {
        let red = HSLFilter.hslToRgb(0, 1, 0.5)
        XCTAssertEqual(red.0, 1, accuracy: 0.005)
        XCTAssertEqual(red.1, 0, accuracy: 0.005)
        XCTAssertEqual(red.2, 0, accuracy: 0.005)

        let gray = HSLFilter.hslToRgb(0, 0, 0.5)
        XCTAssertEqual(gray.0, 0.5, accuracy: 0.005)
        XCTAssertEqual(gray.1, 0.5, accuracy: 0.005)
        XCTAssertEqual(gray.2, 0.5, accuracy: 0.005)
    }
}
