import Foundation

/// UTI-based RAW file type detection (RAF, CR3, DNG, JPG). Phase 1.
public enum RAWFileType {
    case raf
    case cr3
    case dng
    case jpeg
    case unknown
}
