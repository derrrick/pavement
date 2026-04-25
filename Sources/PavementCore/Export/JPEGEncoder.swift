import Foundation
import CoreImage
import CoreGraphics
import ImageIO

public struct JPEGEncoder {
    public init() {}

    /// Writes a JPEG with the given ICC-tagged color space and quality.
    /// EXIF / IPTC / GPS metadata from `metadataSource` is copied into the
    /// output when supplied (PLAN.md §10 risk #9). Pass nil to skip.
    public func write(
        image: CIImage,
        to destination: URL,
        colorSpace: CGColorSpace,
        quality: Float,
        metadataSource: URL? = nil,
        context: CIContext = PipelineContext.shared.context
    ) throws {
        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let qualityKey = CIImageRepresentationOption(
            rawValue: kCGImageDestinationLossyCompressionQuality as String
        )
        var options: [CIImageRepresentationOption: Any] = [
            qualityKey: max(0, min(1, quality))
        ]

        if let metadataSource,
           let extra = JPEGEncoder.metadataDictionary(for: metadataSource) {
            for (key, value) in extra {
                let optKey = CIImageRepresentationOption(rawValue: key)
                options[optKey] = value
            }
        }

        try context.writeJPEGRepresentation(
            of: image,
            to: destination,
            colorSpace: colorSpace,
            options: options
        )
    }

    /// Pulls EXIF / IPTC / GPS / TIFF dictionaries from a source file via
    /// CGImageSource so the encoder can inject them as
    /// CIImageRepresentationOptions (which map onto CGImageDestination
    /// property keys).
    static func metadataDictionary(for source: URL) -> [String: Any]? {
        guard let imageSource = CGImageSourceCreateWithURL(source as CFURL, nil) else { return nil }
        guard let raw = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] else { return nil }

        var passthrough: [String: Any] = [:]
        let keys = [
            kCGImagePropertyExifDictionary,
            kCGImagePropertyTIFFDictionary,
            kCGImagePropertyIPTCDictionary,
            kCGImagePropertyGPSDictionary
        ]
        for key in keys {
            if let value = raw[key as String] {
                passthrough[key as String] = value
            }
        }
        return passthrough.isEmpty ? nil : passthrough
    }
}
