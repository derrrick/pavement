import Foundation
import CoreImage

/// Parametric tone control: contrast, highlights, shadows, whites, blacks,
/// and highlight recovery. All five are composed into a single 1024-sample
/// curve that's applied via a 16³ CIColorCube — same machinery as the
/// user's manual tone curve, just driven by sliders instead of points.
public struct ToneFilter {
    public init() {}

    public func apply(image: CIImage, op: ToneOp) -> CIImage {
        if Self.isIdentity(op) { return image }
        let curve = Self.buildCurve(op: op, samples: 1024)
        let lut = ToneCurveFilter.makeLUT(curve: curve, dimension: 16)
        guard let filter = CIFilter(name: "CIColorCube") else { return image }
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(lut.dimension, forKey: "inputCubeDimension")
        filter.setValue(lut.data, forKey: "inputCubeData")
        return filter.outputImage ?? image
    }

    public static func isIdentity(_ op: ToneOp) -> Bool {
        op.contrast == 0 && op.highlights == 0 && op.shadows == 0 &&
        op.whites == 0 && op.blacks == 0 && op.highlightRecovery == 0
    }

    /// Build a tone curve that composes contrast / highlights / shadows /
    /// whites / blacks / recovery on top of y = x.
    /// Each parameter is normalized into a band of input luminance:
    ///   - blacks (bottom ramp 0..0.30)
    ///   - shadows (bell at 0.30, σ ≈ 0.18)
    ///   - contrast (S-curve pivot at 0.50)
    ///   - highlights (bell at 0.70, σ ≈ 0.18)
    ///   - whites (top ramp 0.70..1.00)
    ///   - recovery (top ramp 0.85..1.00, subtractive)
    public static func buildCurve(op: ToneOp, samples: Int) -> [Float] {
        let contrast = Float(op.contrast) / 100
        let highlights = Float(op.highlights) / 100
        let shadows = Float(op.shadows) / 100
        let whites = Float(op.whites) / 100
        let blacks = Float(op.blacks) / 100
        let recovery = Float(op.highlightRecovery) / 100

        var result = [Float](repeating: 0, count: samples)
        for i in 0..<samples {
            let x = Float(i) / Float(samples - 1)
            var y = x

            // Contrast: linear pivot around 0.5. +100 → slope 1.5.
            y = 0.5 + (y - 0.5) * (1 + contrast * 0.5)

            // Bell curves for shadows / highlights, peak 1.0 at center.
            let shadowBell    = expBell(x: x, center: 0.30, sigma: 0.18)
            let highlightBell = expBell(x: x, center: 0.70, sigma: 0.18)
            y += shadows    * 0.20 * shadowBell
            y += highlights * 0.20 * highlightBell

            // Endpoint ramps: smooth 0..1 toward the extremes.
            let blacksRamp = smoothstep(0.30, 0.0, x)  // ramp UP toward x=0
            let whitesRamp = smoothstep(0.70, 1.0, x)  // ramp UP toward x=1
            y += blacks * 0.25 * blacksRamp
            y += whites * 0.25 * whitesRamp

            // Highlight recovery (positive only): pulls the very top down.
            let recoveryRamp = smoothstep(0.85, 1.0, x)
            y -= max(0, recovery) * 0.30 * recoveryRamp

            result[i] = max(0, min(1, y))
        }
        return result
    }

    @inline(__always)
    private static func expBell(x: Float, center: Float, sigma: Float) -> Float {
        let z = (x - center) / sigma
        return exp(-z * z)
    }

    @inline(__always)
    private static func smoothstep(_ from: Float, _ to: Float, _ x: Float) -> Float {
        let span = to - from
        if abs(span) < 1e-6 { return x < from ? 0 : 1 }
        let t = max(0, min(1, (x - from) / span))
        return t * t * (3 - 2 * t)
    }
}
