import Foundation
import CoreImage

public enum ExportError: Error, CustomStringConvertible {
    case decodeFailed(URL)
    case encodeFailed(URL, String)

    public var description: String {
        switch self {
        case .decodeFailed(let url):
            return "Could not decode \(url.lastPathComponent)"
        case .encodeFailed(let url, let reason):
            return "Could not write \(url.lastPathComponent): \(reason)"
        }
    }
}

public struct Exporter {
    public init() {}

    /// Render `recipe` against `source` and write the result to `destination`
    /// using `preset`. Decode goes through `cachedDecode` if provided so a UI
    /// caller doesn't pay a fresh demosaic per export.
    ///
    /// `specOverride` lets the CLI pass a one-off `ExportSpec` (built from
    /// `--long-edge` / `--quality` flags) without polluting the preset enum.
    /// When non-nil, it wins over `preset.spec`.
    public func export(
        recipe: EditRecipe,
        source: URL,
        preset: ExportPreset,
        destination: URL,
        cachedDecode: CachedDecode? = nil,
        specOverride: ExportSpec? = nil
    ) throws {
        let spec = specOverride ?? preset.spec
        let lensCorrection = recipe.operations.lensCorrection.enabled

        // 1. Decode
        let decoded: CIImage
        if let cachedDecode {
            decoded = try cachedDecode.image(for: source, applyLensCorrection: lensCorrection)
        } else {
            decoded = try CachedDecode.realize(url: source, applyLensCorrection: lensCorrection)
        }

        // 2-13. Pipeline
        let pipelined = PipelineGraph().apply(recipe, to: decoded)

        // 14. Resize
        var image = pipelined
        if let longEdge = spec.longEdge {
            image = Resizer().resize(image: image, longEdge: longEdge)
        }

        // 15. Output sharpening
        image = OutputSharpening().apply(image: image, strength: spec.sharpening)

        // Encode
        switch spec.format {
        case .jpeg:
            try JPEGEncoder().write(
                image: image,
                to: destination,
                colorSpace: spec.colorSpace.cgColorSpace,
                quality: spec.quality,
                metadataSource: source
            )
        case .tiff:
            try TIFFEncoder().write(
                image: image,
                to: destination,
                colorSpace: spec.colorSpace.cgColorSpace,
                bitDepth: spec.bitDepth,
                metadataSource: source
            )
        }
    }

    /// Builds the canonical export destination for a source + preset:
    /// `<source-folder>/_exports/<preset.folderName>/<source-stem>.<ext>`.
    public static func defaultDestination(source: URL, preset: ExportPreset) -> URL {
        let folder = source.deletingLastPathComponent()
            .appendingPathComponent("_exports")
            .appendingPathComponent(preset.spec.folderName)
        let stem = source.deletingPathExtension().lastPathComponent
        let ext: String
        switch preset.spec.format {
        case .jpeg: ext = "jpg"
        case .tiff: ext = "tif"
        }
        return folder.appendingPathComponent("\(stem).\(ext)")
    }
}
