import Foundation
import CoreImage

/// Aggregate L*a*b* statistics for an image, used by MatchLook to derive
/// recipe parameters that pull a current image's color/tone toward a
/// reference's. All in CIE Lab (D65) so the deltas are perceptually
/// meaningful and comparable across content.
public struct ImageStatistics: Equatable {
    public var meanL: Float          // 0..100
    public var stdL: Float
    public var p5L: Float
    public var p95L: Float
    public var meanA: Float          // ~-128..128
    public var meanB: Float
    public var chromaMagnitude: Float  // mean sqrt(a² + b²)
    public var shadowA: Float          // a-mean of pixels with L<33
    public var shadowB: Float
    public var highlightA: Float       // a-mean of pixels with L>66
    public var highlightB: Float
}

public enum ImageStatisticsCalculator {
    public static let defaultMaxDimension = 256

    public static func compute(
        from image: CIImage,
        maxDimension: Int = defaultMaxDimension,
        context: CIContext = PipelineContext.shared.context
    ) -> ImageStatistics {
        let extent = image.extent
        guard extent.width.isFinite, extent.height.isFinite,
              extent.width > 0, extent.height > 0 else {
            return ImageStatistics(meanL: 50, stdL: 1, p5L: 0, p95L: 100,
                                   meanA: 0, meanB: 0, chromaMagnitude: 0,
                                   shadowA: 0, shadowB: 0,
                                   highlightA: 0, highlightB: 0)
        }

        let scale = min(1.0, CGFloat(maxDimension) / max(extent.width, extent.height))
        let scaled = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let scaledExtent = scaled.extent
        let w = max(1, Int(scaledExtent.width.rounded()))
        let h = max(1, Int(scaledExtent.height.rounded()))
        let rowBytes = w * 4

        var bytes = [UInt8](repeating: 0, count: rowBytes * h)
        context.render(
            scaled,
            toBitmap: &bytes,
            rowBytes: rowBytes,
            bounds: CGRect(x: scaledExtent.minX, y: scaledExtent.minY,
                           width: CGFloat(w), height: CGFloat(h)),
            format: .RGBA8,
            colorSpace: ColorSpaces.sRGB
        )

        let total = w * h
        var Ls = [Float](repeating: 0, count: total)
        var As = [Float](repeating: 0, count: total)
        var Bs = [Float](repeating: 0, count: total)
        var chromas = [Float](repeating: 0, count: total)

        var sumShadowA: Float = 0, sumShadowB: Float = 0, shadowCount = 0
        var sumHighA: Float = 0, sumHighB: Float = 0, highCount = 0

        bytes.withUnsafeBufferPointer { buffer in
            let base = buffer.baseAddress!
            for px in 0..<total {
                let i = px * 4
                let R = Float(base[i]) / 255
                let G = Float(base[i + 1]) / 255
                let B = Float(base[i + 2]) / 255
                let lR = srgbToLinear(R)
                let lG = srgbToLinear(G)
                let lB = srgbToLinear(B)
                let x = 0.4124 * lR + 0.3576 * lG + 0.1805 * lB
                let y = 0.2126 * lR + 0.7152 * lG + 0.0722 * lB
                let z = 0.0193 * lR + 0.1192 * lG + 0.9505 * lB
                let fx = labFunc(x / 0.95047)
                let fy = labFunc(y)
                let fz = labFunc(z / 1.08883)
                let L = 116 * fy - 16
                let a = 500 * (fx - fy)
                let b = 200 * (fy - fz)
                Ls[px] = L
                As[px] = a
                Bs[px] = b
                chromas[px] = (a * a + b * b).squareRoot()

                if L < 33 {
                    sumShadowA += a; sumShadowB += b; shadowCount += 1
                } else if L > 66 {
                    sumHighA += a; sumHighB += b; highCount += 1
                }
            }
        }

        let meanL = Ls.reduce(0, +) / Float(total)
        let varianceL = Ls.reduce(0) { $0 + ($1 - meanL) * ($1 - meanL) } / Float(total)
        let stdL = varianceL.squareRoot()

        let sortedL = Ls.sorted()
        let p5Idx = max(0, min(total - 1, Int(Float(total) * 0.05)))
        let p95Idx = max(0, min(total - 1, Int(Float(total) * 0.95)))
        let p5L = sortedL[p5Idx]
        let p95L = sortedL[p95Idx]

        let meanA = As.reduce(0, +) / Float(total)
        let meanB = Bs.reduce(0, +) / Float(total)
        let chromaMag = chromas.reduce(0, +) / Float(total)

        return ImageStatistics(
            meanL: meanL, stdL: stdL, p5L: p5L, p95L: p95L,
            meanA: meanA, meanB: meanB,
            chromaMagnitude: chromaMag,
            shadowA: shadowCount > 0 ? sumShadowA / Float(shadowCount) : 0,
            shadowB: shadowCount > 0 ? sumShadowB / Float(shadowCount) : 0,
            highlightA: highCount > 0 ? sumHighA / Float(highCount) : 0,
            highlightB: highCount > 0 ? sumHighB / Float(highCount) : 0
        )
    }

    // MARK: - Color conversions (sRGB → linear → XYZ → Lab)

    private static func srgbToLinear(_ c: Float) -> Float {
        if c <= 0.04045 { return c / 12.92 }
        return pow((c + 0.055) / 1.055, 2.4)
    }

    private static func labFunc(_ t: Float) -> Float {
        let delta: Float = 6.0 / 29.0
        if t > delta * delta * delta {
            return pow(t, 1.0 / 3.0)
        }
        return t / (3 * delta * delta) + 4.0 / 29.0
    }
}
