import Foundation
import CoreImage

/// Three-way color grading: shadow / midtone / highlight tints + a global
/// wheel. Each wheel contributes a hue-shifted color delta weighted by
/// the pixel's luminance band, plus a luminance offset. Implemented as a
/// 16³ CIColorCube LUT (same approach as HSLFilter) so a single GPU pass
/// applies everything.
public struct ColorGradingFilter {
    public static let lutDimension = 16

    /// Maximum color shift per wheel at sat=100. Empirically tuned to match
    /// what users expect from a Color Balance wheel — small enough that
    /// extreme settings don't blow out the image, large enough that the
    /// effect is clearly visible.
    public static let tintStrength: Float = 0.30
    public static let lumStrength: Float = 0.25

    public init() {}

    public func apply(image: CIImage, op: ColorGradingOp) -> CIImage {
        if Self.isIdentity(op) { return image }
        let lut = Self.makeLUT(op: op, dimension: Self.lutDimension)
        guard let filter = CIFilter(name: "CIColorCube") else { return image }
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(lut.dimension, forKey: "inputCubeDimension")
        filter.setValue(lut.data, forKey: "inputCubeData")
        return filter.outputImage ?? image
    }

    public static func isIdentity(_ op: ColorGradingOp) -> Bool {
        let wheels = [op.shadows, op.midtones, op.highlights, op.global]
        return wheels.allSatisfy { $0.hue == 0 && $0.sat == 0 && $0.lum == 0 }
    }

    static func makeLUT(op: ColorGradingOp, dimension n: Int) -> ToneCurveFilter.LUT {
        var bytes = [Float](repeating: 0, count: n * n * n * 4)
        let denom = Float(n - 1)

        // Pre-compute per-wheel color deltas so the inner loop just does
        // luminance weighting.
        let shadowDelta = colorDelta(op.shadows)
        let midDelta = colorDelta(op.midtones)
        let highDelta = colorDelta(op.highlights)
        let globalDelta = colorDelta(op.global)

        // Balance shifts the boundaries between regions: positive favors
        // highlights (more pixels classified as highlight), negative favors
        // shadows. Range -100..100 → ±0.15 boundary shift.
        let balanceShift = Float(op.balance) / 100 * 0.15

        for b in 0..<n {
            for g in 0..<n {
                for r in 0..<n {
                    let R = Float(r) / denom
                    let G = Float(g) / denom
                    let B = Float(b) / denom
                    let L = R * 0.2126 + G * 0.7152 + B * 0.0722

                    // Region weights peak at 0.0 / 0.5 / 1.0 with smooth
                    // bell-curve falloff. Balance shifts midtone center.
                    let midCenter: Float = 0.5 + balanceShift
                    let shadowW = max(0, 1 - L / 0.4)
                    let midW = max(0, 1 - abs(L - midCenter) / 0.30)
                    let highW = max(0, (L - 0.6) / 0.4)

                    var dR = shadowDelta.r * shadowW + midDelta.r * midW + highDelta.r * highW + globalDelta.r
                    var dG = shadowDelta.g * shadowW + midDelta.g * midW + highDelta.g * highW + globalDelta.g
                    var dB = shadowDelta.b * shadowW + midDelta.b * midW + highDelta.b * highW + globalDelta.b
                    let dL = shadowDelta.lum * shadowW + midDelta.lum * midW + highDelta.lum * highW + globalDelta.lum

                    dR += dL
                    dG += dL
                    dB += dL

                    let outR = max(0, min(1, R + dR))
                    let outG = max(0, min(1, G + dG))
                    let outB = max(0, min(1, B + dB))

                    let i = (b * n * n + g * n + r) * 4
                    bytes[i + 0] = outR
                    bytes[i + 1] = outG
                    bytes[i + 2] = outB
                    bytes[i + 3] = 1
                }
            }
        }
        let data = bytes.withUnsafeBufferPointer { Data(buffer: $0) }
        return ToneCurveFilter.LUT(dimension: n, data: data)
    }

    private struct Delta {
        let r: Float
        let g: Float
        let b: Float
        let lum: Float
    }

    private static func colorDelta(_ wheel: GradingWheel) -> Delta {
        let satNorm = Float(wheel.sat) / 100         // 0..1 typical, can be negative
        let lumNorm = Float(wheel.lum) / 100
        let hue = Float(wheel.hue)

        if satNorm == 0 && lumNorm == 0 {
            return Delta(r: 0, g: 0, b: 0, lum: 0)
        }

        // Convert hue + magnitude to an RGB tint relative to mid-gray.
        let mag = abs(satNorm)
        let (tR, tG, tB) = HSLFilter.hslToRgb(hue, mag, 0.5)
        let sign: Float = satNorm < 0 ? -1 : 1
        let factor = mag * tintStrength * sign

        return Delta(
            r: (tR - 0.5) * factor,
            g: (tG - 0.5) * factor,
            b: (tB - 0.5) * factor,
            lum: lumNorm * lumStrength
        )
    }
}
