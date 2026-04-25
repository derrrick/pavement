import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins

public struct Resizer {
    public init() {}

    /// Lanczos downscale so the long edge lands at `longEdge` pixels. If the
    /// image's long edge is already smaller, returns the input unchanged.
    public func resize(image: CIImage, longEdge: Int) -> CIImage {
        let extent = image.extent
        let currentLong = max(extent.width, extent.height)
        guard currentLong > CGFloat(longEdge), longEdge > 0 else { return image }

        let scale = CGFloat(longEdge) / currentLong
        let filter = CIFilter.lanczosScaleTransform()
        filter.inputImage = image
        filter.scale = Float(scale)
        filter.aspectRatio = 1.0
        return filter.outputImage ?? image
    }
}
