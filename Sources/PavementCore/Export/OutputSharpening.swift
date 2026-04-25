import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins

public struct OutputSharpening {
    public init() {}

    public func apply(image: CIImage, strength: SharpeningStrength) -> CIImage {
        guard strength != .none else { return image }
        let filter = CIFilter.unsharpMask()
        filter.inputImage = image
        filter.intensity = strength.amount
        filter.radius = strength.radius
        return filter.outputImage ?? image
    }
}
