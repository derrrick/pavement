import Foundation
import CoreImage

public enum DecodeError: Error, CustomStringConvertible {
    case unsupported(url: URL)
    case outputUnavailable(url: URL)

    public var description: String {
        switch self {
        case .unsupported(let url):       return "Unsupported source: \(url.lastPathComponent)"
        case .outputUnavailable(let url): return "Decoder produced no output for \(url.lastPathComponent)"
        }
    }
}

public struct DecodeStage {
    public init() {}

    /// Decodes a source file to a linear scene-referred CIImage in the
    /// engine's working color space. RAW files use CIRAWFilter; JPEGs use
    /// CIImage(contentsOf:). Unsupported types throw `.unsupported`.
    public func decode(url: URL) throws -> CIImage {
        let type = RAWFileType.from(url: url)

        if type.isRaw {
            guard let filter = CIRAWFilter(imageURL: url) else {
                throw DecodeError.unsupported(url: url)
            }
            // Skip Apple's gamut map so Fujifilm RAFs (and other wide-gamut
            // sources) don't double-cook a film simulation; PLAN.md §7.
            filter.isGamutMappingEnabled = false
            guard let image = filter.outputImage else {
                throw DecodeError.outputUnavailable(url: url)
            }
            return image
        }

        if type == .jpeg {
            guard let image = CIImage(contentsOf: url) else {
                throw DecodeError.unsupported(url: url)
            }
            return image
        }

        throw DecodeError.unsupported(url: url)
    }
}
