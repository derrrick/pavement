import Foundation
import CoreImage

/// Applies an imported 3D LUT (.cube → CIColorCube) as a final color
/// transform. Style-level LUTs ride after the rest of the pipeline so
/// the parametric adjustments still operate in linear-ish space and the
/// LUT acts as a "look" applied to the result — same order Lightroom
/// and Capture One use.
public struct LUTFilter {
    public init() {}

    public func apply(image: CIImage, lut: LUTData?) -> CIImage {
        guard let lut else { return image }
        guard let filter = CIFilter(name: "CIColorCube") else { return image }
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(lut.dimension, forKey: "inputCubeDimension")
        filter.setValue(lut.data, forKey: "inputCubeData")
        return filter.outputImage ?? image
    }
}
