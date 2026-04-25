import XCTest
import CoreImage
@testable import PavementCore

final class ToneFilterTests: XCTestCase {
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

    private func curveSample(at x: Float, op: ToneOp) -> Float {
        let curve = ToneFilter.buildCurve(op: op, samples: 1024)
        let idx = Int(x * Float(curve.count - 1))
        return curve[idx]
    }

    func testIdentityCurveIsLinear() {
        let curve = ToneFilter.buildCurve(op: ToneOp(), samples: 256)
        for i in 0..<256 {
            let expected = Float(i) / 255
            XCTAssertEqual(curve[i], expected, accuracy: 0.005)
        }
    }

    func testWhitesPositiveLiftsTopRange() {
        var op = ToneOp()
        op.whites = 80
        XCTAssertGreaterThan(curveSample(at: 0.95, op: op), 0.99)
        // Mid-tones should barely move
        XCTAssertEqual(curveSample(at: 0.50, op: op), 0.50, accuracy: 0.02)
    }

    func testWhitesNegativePullsTopRange() {
        var op = ToneOp()
        op.whites = -80
        XCTAssertLessThan(curveSample(at: 0.95, op: op), 0.85)
    }

    func testBlacksNegativeCrushesBottom() {
        var op = ToneOp()
        op.blacks = -80
        XCTAssertLessThan(curveSample(at: 0.05, op: op), 0.02)
        // Mid-tones should barely move
        XCTAssertEqual(curveSample(at: 0.50, op: op), 0.50, accuracy: 0.02)
    }

    func testBlacksPositiveLiftsBottom() {
        var op = ToneOp()
        op.blacks = 80
        XCTAssertGreaterThan(curveSample(at: 0.05, op: op), 0.10)
    }

    func testHighlightRecoveryPullsClipping() {
        var op = ToneOp()
        op.highlightRecovery = 100
        XCTAssertLessThan(curveSample(at: 0.95, op: op), 0.92)
    }

    func testWhitesActuallyAffectImage() {
        var op = ToneOp()
        op.whites = 100
        let bright = solid(red: 0.9, green: 0.9, blue: 0.9)
        let out = sample(ToneFilter().apply(image: bright, op: op))
        XCTAssertGreaterThan(out[0], 0.95, "Whites + 100 should brighten near-white pixels")
    }

    func testBlacksActuallyAffectImage() {
        var op = ToneOp()
        op.blacks = -100
        let dark = solid(red: 0.1, green: 0.1, blue: 0.1)
        let out = sample(ToneFilter().apply(image: dark, op: op))
        XCTAssertLessThan(out[0], 0.10, "Blacks - 100 should crush near-black pixels")
    }

    func testContrastSCurves() {
        var op = ToneOp()
        op.contrast = 50
        XCTAssertLessThan(curveSample(at: 0.25, op: op), 0.25)    // pulled down
        XCTAssertGreaterThan(curveSample(at: 0.75, op: op), 0.75) // pushed up
        XCTAssertEqual(curveSample(at: 0.50, op: op), 0.50, accuracy: 0.005) // pivot
    }

    func testIdentityImageIsByteIdentity() {
        let input = solid(red: 0.4, green: 0.6, blue: 0.2)
        let output = ToneFilter().apply(image: input, op: ToneOp())
        let i = sample(input)
        let o = sample(output)
        for (a, b) in zip(i, o) {
            XCTAssertEqual(a, b, accuracy: 0.005)
        }
    }
}
