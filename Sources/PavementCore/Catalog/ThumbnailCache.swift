import Foundation
import CoreImage
import ImageIO

public struct ThumbnailCache {
    public static let cacheSubdirectory = "_pavement/thumbnails"
    public static let maxDimension: CGFloat = 512
    public static let jpegQuality: CGFloat = 0.7

    public init() {}

    /// `<source-folder>/_pavement/thumbnails/<stem>.<ext>.jpg`. The original
    /// extension is included so DSCF1234.RAF and DSCF1234.JPG don't collide.
    public static func thumbnailURL(for source: URL) -> URL {
        let folder = source.deletingLastPathComponent()
        let stem = source.deletingPathExtension().lastPathComponent
        let ext = source.pathExtension.lowercased()
        let name = ext.isEmpty ? "\(stem).jpg" : "\(stem).\(ext).jpg"
        return folder
            .appendingPathComponent(cacheSubdirectory)
            .appendingPathComponent(name)
    }

    public func cached(for source: URL) -> URL? {
        let url = Self.thumbnailURL(for: source)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// Decodes the source, scales the long edge to `maxDimension`, writes a
    /// sRGB-tagged JPEG into the per-folder cache directory.
    @discardableResult
    public func generate(
        for source: URL,
        decoder: DecodeStage = DecodeStage(),
        context: CIContext = PipelineContext.shared.context
    ) throws -> URL {
        let dest = Self.thumbnailURL(for: source)
        try FileManager.default.createDirectory(
            at: dest.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let image = try decoder.decode(url: source)
        let extent = image.extent
        let longEdge = max(extent.width, extent.height)
        let scale = longEdge > 0 ? min(1.0, Self.maxDimension / longEdge) : 1.0
        let scaled = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        let qualityKey = CIImageRepresentationOption(
            rawValue: kCGImageDestinationLossyCompressionQuality as String
        )
        let options: [CIImageRepresentationOption: Any] = [
            qualityKey: Self.jpegQuality
        ]

        try context.writeJPEGRepresentation(
            of: scaled,
            to: dest,
            colorSpace: ColorSpaces.sRGB,
            options: options
        )
        return dest
    }

    /// Returns a cached thumbnail if present, generating one otherwise.
    @discardableResult
    public func ensure(
        for source: URL,
        decoder: DecodeStage = DecodeStage(),
        context: CIContext = PipelineContext.shared.context
    ) throws -> URL {
        if let cached = cached(for: source) {
            return cached
        }
        return try generate(for: source, decoder: decoder, context: context)
    }
}
