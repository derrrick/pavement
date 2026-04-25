import Foundation
import CoreImage

/// Per-band hue/saturation/luminance via a 16³ 3D LUT consumed by CIColorCube.
/// LUT generation runs on CPU per render (~120K float ops, sub-millisecond on
/// M-series), keeping slider drags responsive.
public struct HSLFilter {
    public static let lutDimension = 16
    public static let bandFalloffDegrees: Float = 30

    /// Canonical band hue centers (degrees, 0-360).
    public static let bandCenters: [Float] = [0, 30, 60, 120, 180, 240, 280, 320]

    public init() {}

    public func apply(image: CIImage, op: HSLOp) -> CIImage {
        guard !Self.isIdentity(op) else { return image }
        let lut = Self.makeLUT(op: op, dimension: Self.lutDimension)
        guard let filter = CIFilter(name: "CIColorCube") else { return image }
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(lut.dimension, forKey: "inputCubeDimension")
        filter.setValue(lut.data, forKey: "inputCubeData")
        return filter.outputImage ?? image
    }

    // MARK: - LUT

    public struct LUT {
        public let dimension: Int
        public let data: Data
    }

    public static func isIdentity(_ op: HSLOp) -> Bool {
        let bands = [op.red, op.orange, op.yellow, op.green, op.aqua, op.blue, op.purple, op.magenta]
        return bands.allSatisfy { $0.h == 0 && $0.s == 0 && $0.l == 0 }
    }

    public static func makeLUT(op: HSLOp, dimension n: Int) -> LUT {
        let bands: [HSLBand] = [op.red, op.orange, op.yellow, op.green, op.aqua, op.blue, op.purple, op.magenta]
        var bytes = [Float](repeating: 0, count: n * n * n * 4)
        let denom = Float(n - 1)
        for b in 0..<n {
            for g in 0..<n {
                for r in 0..<n {
                    let R = Float(r) / denom
                    let G = Float(g) / denom
                    let B = Float(b) / denom
                    let adjusted = adjust(r: R, g: G, b: B, bands: bands)
                    let i = (b * n * n + g * n + r) * 4
                    bytes[i + 0] = adjusted.0
                    bytes[i + 1] = adjusted.1
                    bytes[i + 2] = adjusted.2
                    bytes[i + 3] = 1.0
                }
            }
        }
        let data = bytes.withUnsafeBufferPointer { Data(buffer: $0) }
        return LUT(dimension: n, data: data)
    }

    private static func adjust(r: Float, g: Float, b: Float, bands: [HSLBand]) -> (Float, Float, Float) {
        var (h, s, v) = rgbToHsv(r, g, b)

        // Gate by saturation: gray/near-gray pixels have undefined hue and
        // shouldn't be classified into any color band. Linear ramp from
        // s=0 (no effect) to s=0.15 (full effect).
        let satGate: Float = min(1, max(0, s / 0.15))
        if satGate <= 0 {
            return (r, g, b)
        }

        var deltaH: Float = 0
        var deltaS: Float = 0
        var deltaL: Float = 0
        var totalWeight: Float = 0

        for (index, center) in bandCenters.enumerated() {
            let raw = abs(h - center)
            let dist = min(raw, 360 - raw)
            let weight = max(0, 1 - dist / bandFalloffDegrees)
            guard weight > 0 else { continue }
            let band = bands[index]
            deltaH += weight * Float(band.h) * 0.6
            deltaS += weight * Float(band.s) / 100
            deltaL += weight * Float(band.l) / 200
            totalWeight += weight
        }

        if totalWeight > 0 {
            let inv = 1.0 / totalWeight
            deltaH *= inv
            deltaS *= inv
            deltaL *= inv
        }

        deltaH *= satGate
        deltaS *= satGate
        deltaL *= satGate

        h = (h + deltaH).truncatingRemainder(dividingBy: 360)
        if h < 0 { h += 360 }
        s = max(0, min(1, s + deltaS * s))
        v = max(0, min(1, v + deltaL))

        return hsvToRgb(h, s, v)
    }

    private static func rgbToHsv(_ r: Float, _ g: Float, _ b: Float) -> (Float, Float, Float) {
        let cmax = max(r, max(g, b))
        let cmin = min(r, min(g, b))
        let d = cmax - cmin
        var h: Float = 0
        if d > 0.000001 {
            if cmax == r {
                h = ((g - b) / d).truncatingRemainder(dividingBy: 6)
            } else if cmax == g {
                h = ((b - r) / d) + 2
            } else {
                h = ((r - g) / d) + 4
            }
            h *= 60
            if h < 0 { h += 360 }
        }
        let s: Float = cmax > 0.000001 ? d / cmax : 0
        return (h, s, cmax)
    }

    private static func hsvToRgb(_ h: Float, _ s: Float, _ v: Float) -> (Float, Float, Float) {
        let c = v * s
        let hp = h / 60
        let x = c * (1 - abs(hp.truncatingRemainder(dividingBy: 2) - 1))
        var r: Float = 0, g: Float = 0, b: Float = 0
        if hp >= 0 && hp < 1 { r = c; g = x }
        else if hp < 2 { r = x; g = c }
        else if hp < 3 { g = c; b = x }
        else if hp < 4 { g = x; b = c }
        else if hp < 5 { r = x; b = c }
        else { r = c; b = x }
        let m = v - c
        return (r + m, g + m, b + m)
    }
}
