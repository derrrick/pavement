import Foundation
import CoreImage

public struct Histogram: Equatable, Sendable {
    public let red: [Int]
    public let green: [Int]
    public let blue: [Int]
    public let luminance: [Int]

    public init(red: [Int], green: [Int], blue: [Int], luminance: [Int]) {
        self.red = red
        self.green = green
        self.blue = blue
        self.luminance = luminance
    }

    public static let empty = Histogram(
        red: Array(repeating: 0, count: 256),
        green: Array(repeating: 0, count: 256),
        blue: Array(repeating: 0, count: 256),
        luminance: Array(repeating: 0, count: 256)
    )

    public var maxRGB: Int {
        max((red.max() ?? 0), max(green.max() ?? 0, blue.max() ?? 0))
    }
}

/// Walks a downsampled sRGB-tagged bitmap render of the post-pipeline image
/// and counts per-channel + luminance occurrences into 256 bins each.
/// Phase 2 ships this on CPU; the metal compute shader path lives in
/// Filters/Metal/ and is wired in when 256² CPU passes start showing up
/// on the per-frame budget.
public struct HistogramComputer {
    public static let defaultMaxDimension = 256

    public init() {}

    public func compute(image: CIImage, maxDimension: Int = HistogramComputer.defaultMaxDimension) -> Histogram {
        let extent = image.extent
        guard extent.width.isFinite, extent.height.isFinite,
              extent.width > 0, extent.height > 0 else { return .empty }

        let scale = min(1.0, CGFloat(maxDimension) / max(extent.width, extent.height))
        let scaled = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let scaledExtent = scaled.extent
        let w = max(1, Int(scaledExtent.width.rounded()))
        let h = max(1, Int(scaledExtent.height.rounded()))
        let rowBytes = w * 4

        var bytes = [UInt8](repeating: 0, count: rowBytes * h)
        PipelineContext.shared.context.render(
            scaled,
            toBitmap: &bytes,
            rowBytes: rowBytes,
            bounds: CGRect(x: scaledExtent.minX, y: scaledExtent.minY,
                           width: CGFloat(w), height: CGFloat(h)),
            format: .RGBA8,
            colorSpace: ColorSpaces.sRGB
        )

        var r = [Int](repeating: 0, count: 256)
        var g = [Int](repeating: 0, count: 256)
        var b = [Int](repeating: 0, count: 256)
        var l = [Int](repeating: 0, count: 256)

        bytes.withUnsafeBufferPointer { buffer in
            let base = buffer.baseAddress!
            let total = w * h
            for px in 0..<total {
                let i = px * 4
                let R = Int(base[i])
                let G = Int(base[i + 1])
                let B = Int(base[i + 2])
                r[R] += 1
                g[G] += 1
                b[B] += 1
                let lum = Int((0.2126 * Double(R) + 0.7152 * Double(G) + 0.0722 * Double(B)).rounded())
                l[min(255, max(0, lum))] += 1
            }
        }

        return Histogram(red: r, green: g, blue: b, luminance: l)
    }
}
