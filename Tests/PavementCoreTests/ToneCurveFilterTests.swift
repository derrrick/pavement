import XCTest
import CoreImage
@testable import PavementCore

/// Per-channel curve regressions: previously CIColorMap turned every image
/// monochrome. These tests assert the curve preserves chrominance.
final class ToneCurveFilterTests: XCTestCase {
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

    private func solid(red: CGFloat, green: CGFloat, blue: CGFloat) -> CIImage {
        CIImage(color: CIColor(red: red, green: green, blue: blue))
            .cropped(to: CGRect(x: 0, y: 0, width: 4, height: 4))
    }

    func testIdentityCurveIsByteIdentity() {
        let input = solid(red: 0.7, green: 0.2, blue: 0.4)
        let output = ToneCurveFilter().apply(image: input, op: ToneCurveOp())
        let inS = sample(input)
        let outS = sample(output)
        for (i, o) in zip(inS, outS) {
            XCTAssertEqual(i, o, accuracy: 0.005)
        }
    }

    /// Regression: CIColorMap with a monochrome gradient collapsed every
    /// image to gray. With the 3D LUT, color must survive.
    func testNonIdentityCurvePreservesChrominance() {
        var op = ToneCurveOp()
        op.rgb = [[0, 0], [0.25, 0.18], [0.75, 0.82], [1, 1]] // S-curve
        let input = solid(red: 0.8, green: 0.2, blue: 0.2)
        let output = ToneCurveFilter().apply(image: input, op: op)
        let s = sample(output)
        XCTAssertGreaterThan(s[0], s[1] + 0.2,
                             "Red channel should remain dominant after the curve")
        XCTAssertGreaterThan(s[0], s[2] + 0.2,
                             "Red channel should remain dominant after the curve")
    }

    func testSCurvePushesShadowsDownAndHighlightsUp() {
        var op = ToneCurveOp()
        op.rgb = [[0, 0], [0.25, 0.10], [0.75, 0.90], [1, 1]] // strong S
        let dark = solid(red: 0.25, green: 0.25, blue: 0.25)
        let darkOut = sample(ToneCurveFilter().apply(image: dark, op: op))
        XCTAssertLessThan(darkOut[0], 0.30, "Shadows should be pulled down")

        let bright = solid(red: 0.75, green: 0.75, blue: 0.75)
        let brightOut = sample(ToneCurveFilter().apply(image: bright, op: op))
        XCTAssertGreaterThan(brightOut[0], 0.85, "Highlights should be lifted")
    }

    func testCurveIsAppliedPerChannelIndependently() {
        var op = ToneCurveOp()
        // A nasty curve that crushes mids and lifts highlights.
        op.rgb = [[0, 0], [0.5, 0.2], [1, 1]]
        let pinkish = solid(red: 0.9, green: 0.5, blue: 0.5)
        let out = sample(ToneCurveFilter().apply(image: pinkish, op: op))
        // Red was at 0.9 → curve(0.9) ≈ high. Green/Blue at 0.5 → curve(0.5) ≈ 0.2.
        // Each channel mapped independently — the output should still be
        // distinctly red-dominant.
        XCTAssertGreaterThan(out[0], 0.7)
        XCTAssertLessThan(out[1], 0.4)
        XCTAssertLessThan(out[2], 0.4)
    }
}
