import Foundation
import CoreImage

/// Per-channel tone curve via a 16³ 3D LUT consumed by CIColorCube.
/// CIColorMap was the wrong tool — it does *gradient mapping*: each output
/// pixel's color comes from looking up the gradient image at the source's
/// luminance, which collapses chrominance to whatever the gradient encodes.
/// A monochrome gradient turns the image B&W.
///
/// CIColorCube avoids this by sampling each axis independently — at LUT cell
/// (R, G, B) we store (curve(R), curve(G), curve(B)), so each channel is
/// remapped through the curve without cross-channel collapse.
public struct ToneCurveFilter {
    public static let curveSamples = 1024
    public static let lutDimension = 16

    public init() {}

    public func apply(image: CIImage, op: ToneCurveOp) -> CIImage {
        guard !Self.isIdentity(op.rgb) else { return image }
        let curve = ToneCurveInterpolator.sample(controlPoints: op.rgb, samples: Self.curveSamples)
        let lut = Self.makeLUT(curve: curve, dimension: Self.lutDimension)
        guard let filter = CIFilter(name: "CIColorCube") else { return image }
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(lut.dimension, forKey: "inputCubeDimension")
        filter.setValue(lut.data, forKey: "inputCubeData")
        return filter.outputImage ?? image
    }

    public static func isIdentity(_ pts: [[Double]]) -> Bool {
        guard pts.count == 2 else { return false }
        return pts == [[0, 0], [1, 1]]
    }

    public struct LUT {
        public let dimension: Int
        public let data: Data
    }

    public static func makeLUT(curve: [Float], dimension n: Int) -> LUT {
        var bytes = [Float](repeating: 0, count: n * n * n * 4)
        let denom = Float(n - 1)
        for b in 0..<n {
            for g in 0..<n {
                for r in 0..<n {
                    let R = Float(r) / denom
                    let G = Float(g) / denom
                    let B = Float(b) / denom
                    let i = (b * n * n + g * n + r) * 4
                    bytes[i + 0] = lookup(R, in: curve)
                    bytes[i + 1] = lookup(G, in: curve)
                    bytes[i + 2] = lookup(B, in: curve)
                    bytes[i + 3] = 1.0
                }
            }
        }
        let data = bytes.withUnsafeBufferPointer { Data(buffer: $0) }
        return LUT(dimension: n, data: data)
    }

    /// Linearly interpolate `x` (clamped to 0..1) into `curve`.
    private static func lookup(_ x: Float, in curve: [Float]) -> Float {
        let clamped = max(0, min(1, x))
        let idx = clamped * Float(curve.count - 1)
        let i0 = Int(idx)
        let i1 = min(i0 + 1, curve.count - 1)
        let t = idx - Float(i0)
        return curve[i0] * (1 - t) + curve[i1] * t
    }
}
