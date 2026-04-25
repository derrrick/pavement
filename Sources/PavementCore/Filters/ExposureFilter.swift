import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins

public struct ExposureFilter {
    public init() {}

    public func apply(image: CIImage, op: ExposureOp) -> CIImage {
        guard op.ev != 0 else { return image }
        let filter = CIFilter.exposureAdjust()
        filter.inputImage = image
        filter.ev = Float(op.ev)
        return filter.outputImage ?? image
    }
}
