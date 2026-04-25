import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins

public struct WhiteBalanceFilter {
    /// Reference neutral assumed when the user provides a custom WB. The user's
    /// `temp/tint` describe what the WHITE POINT should look like; CITemperatureAndTint
    /// shifts the image so 6500K (`neutral`) becomes the requested
    /// `targetNeutral`.
    public static let referenceTemperature: CGFloat = 6500

    public init() {}

    public func apply(image: CIImage, op: WhiteBalanceOp) -> CIImage {
        guard op.mode == WhiteBalanceOp.custom else { return image }
        let filter = CIFilter.temperatureAndTint()
        filter.inputImage = image
        filter.neutral = CIVector(x: Self.referenceTemperature, y: 0)
        filter.targetNeutral = CIVector(x: CGFloat(op.temp), y: CGFloat(op.tint))
        return filter.outputImage ?? image
    }
}
