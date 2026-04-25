import Foundation

/// Instagram (1080x1350 sRGB JPEG 90), Web (2048-long sRGB JPEG 80), Print (full P3 16-bit TIFF). Phase 3.
public enum ExportPreset {
    case instagram
    case web
    case print
}
