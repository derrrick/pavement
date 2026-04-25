import Foundation
import CoreImage

/// Desaturates everything outside the active hue band so you can see
/// exactly which pixels an HSL adjustment will hit. Inspired by
/// Capture One's "view selected color range" toggle in the Color
/// Editor — it's the visualizer that makes per-band tweaks safe.
public struct IsolationFilter {
    /// Falloff width on either side of the band's center, in degrees.
    /// Slightly narrower than HSLFilter's edit falloff so the visualization
    /// feels precise.
    public static let falloffDegrees: Float = 35

    /// How much we desaturate non-band pixels (1.0 = fully gray, 0 = identity).
    public static let outsideDesaturation: Float = 0.85

    public init() {}

    public func apply(image: CIImage, bandIndex: Int) -> CIImage {
        guard bandIndex >= 0, bandIndex < HSLFilter.bandCenters.count else { return image }
        let center = HSLFilter.bandCenters[bandIndex]
        let lut = Self.makeLUT(center: center, dimension: 16)
        guard let filter = CIFilter(name: "CIColorCube") else { return image }
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(lut.dimension, forKey: "inputCubeDimension")
        filter.setValue(lut.data, forKey: "inputCubeData")
        return filter.outputImage ?? image
    }

    static func makeLUT(center: Float, dimension n: Int) -> ToneCurveFilter.LUT {
        var bytes = [Float](repeating: 0, count: n * n * n * 4)
        let denom = Float(n - 1)
        for b in 0..<n {
            for g in 0..<n {
                for r in 0..<n {
                    let R = Float(r) / denom
                    let G = Float(g) / denom
                    let B = Float(b) / denom
                    let (h, s, l) = HSLFilter.rgbToHsl(R, G, B)
                    let raw = abs(h - center)
                    let dist = min(raw, 360 - raw)
                    let weight = max(0, 1 - dist / falloffDegrees)
                    // Outside band: desaturate; inside: keep full saturation.
                    // Linear blend with weight = "in band" amount.
                    let preserve = weight + (1 - weight) * (1 - outsideDesaturation)
                    let newS = s * preserve
                    let (R2, G2, B2) = HSLFilter.hslToRgb(h, newS, l)
                    let i = (b * n * n + g * n + r) * 4
                    bytes[i + 0] = R2
                    bytes[i + 1] = G2
                    bytes[i + 2] = B2
                    bytes[i + 3] = 1
                }
            }
        }
        let data = bytes.withUnsafeBufferPointer { Data(buffer: $0) }
        return ToneCurveFilter.LUT(dimension: n, data: data)
    }
}
