import Foundation
import CoreImage
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

public struct TIFFEncoder {
    public init() {}

    /// Writes a TIFF with the given ICC-tagged color space and bit depth
    /// (8 or 16). EXIF / IPTC / GPS metadata is copied from `metadataSource`
    /// when supplied. ImageIO is used end-to-end so the output is portable
    /// to Photoshop and Preview without colour shift.
    public func write(
        image: CIImage,
        to destination: URL,
        colorSpace: CGColorSpace,
        bitDepth: Int,
        metadataSource: URL? = nil,
        context: CIContext = PipelineContext.shared.context
    ) throws {
        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let extent = image.extent
        guard extent.width.isFinite, extent.height.isFinite,
              extent.width > 0, extent.height > 0 else {
            throw ExportError.encodeFailed(destination, "Invalid image extent")
        }

        let format: CIFormat = (bitDepth == 16) ? .RGBA16 : .RGBA8
        guard let cgImage = context.createCGImage(
            image,
            from: extent,
            format: format,
            colorSpace: colorSpace
        ) else {
            throw ExportError.encodeFailed(destination, "Could not realize CGImage")
        }

        guard let dest = CGImageDestinationCreateWithURL(
            destination as CFURL,
            UTType.tiff.identifier as CFString,
            1,
            nil
        ) else {
            throw ExportError.encodeFailed(destination, "Could not create CGImageDestination")
        }

        var properties: [String: Any] = [
            kCGImageDestinationLossyCompressionQuality as String: 1.0,
            kCGImagePropertyHasAlpha as String: false
        ]
        if let metadataSource,
           let extra = JPEGEncoder.metadataDictionary(for: metadataSource) {
            for (key, value) in extra {
                properties[key] = value
            }
        }

        CGImageDestinationAddImage(dest, cgImage, properties as CFDictionary)
        guard CGImageDestinationFinalize(dest) else {
            throw ExportError.encodeFailed(destination, "Finalize failed")
        }
    }
}
