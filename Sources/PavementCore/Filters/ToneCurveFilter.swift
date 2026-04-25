import Foundation
import CoreImage

public struct ToneCurveFilter {
    public static let lutWidth = 1024

    public init() {}

    public func apply(image: CIImage, op: ToneCurveOp) -> CIImage {
        guard !Self.isIdentity(op.rgb) else { return image }
        let samples = ToneCurveInterpolator.sample(controlPoints: op.rgb, samples: Self.lutWidth)
        guard let gradient = Self.makeGradient(samples: samples) else { return image }
        guard let filter = CIFilter(name: "CIColorMap") else { return image }
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(gradient, forKey: "inputGradientImage")
        return filter.outputImage ?? image
    }

    public static func isIdentity(_ pts: [[Double]]) -> Bool {
        guard pts.count == 2 else { return false }
        return pts == [[0, 0], [1, 1]]
    }

    private static func makeGradient(samples: [Float]) -> CIImage? {
        var bytes = [Float](repeating: 0, count: samples.count * 4)
        for i in 0..<samples.count {
            bytes[i * 4 + 0] = samples[i]
            bytes[i * 4 + 1] = samples[i]
            bytes[i * 4 + 2] = samples[i]
            bytes[i * 4 + 3] = 1
        }
        let data = bytes.withUnsafeBufferPointer { Data(buffer: $0) }
        return CIImage(
            bitmapData: data,
            bytesPerRow: samples.count * MemoryLayout<Float>.size * 4,
            size: CGSize(width: samples.count, height: 1),
            format: .RGBAf,
            colorSpace: ColorSpaces.displayP3
        )
    }
}
