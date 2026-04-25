import Foundation

public enum RAWFileType: String, Equatable, CaseIterable {
    case raf
    case cr3
    case dng
    case jpeg
    case unknown

    public static func from(url: URL) -> RAWFileType {
        switch url.pathExtension.lowercased() {
        case "raf": return .raf
        case "cr3": return .cr3
        case "dng": return .dng
        case "jpg", "jpeg": return .jpeg
        default: return .unknown
        }
    }

    /// True for proprietary camera RAW formats Pavement edits non-destructively.
    public var isRaw: Bool {
        switch self {
        case .raf, .cr3, .dng: return true
        case .jpeg, .unknown:  return false
        }
    }

    /// True for any source format Pavement can ingest (RAW + JPEG passthrough).
    public var isIngestible: Bool {
        self != .unknown
    }
}
