import Foundation
import ImageIO

public struct ExifData: Equatable {
    public var captureTime: Date?
    public var camera: String?
    public var lens: String?
    public var iso: Int?
    public var pixelWidth: Int?
    public var pixelHeight: Int?

    public init(
        captureTime: Date? = nil,
        camera: String? = nil,
        lens: String? = nil,
        iso: Int? = nil,
        pixelWidth: Int? = nil,
        pixelHeight: Int? = nil
    ) {
        self.captureTime = captureTime
        self.camera = camera
        self.lens = lens
        self.iso = iso
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
    }
}

public struct ExifReader {
    public init() {}

    public func read(url: URL) -> ExifData? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        guard let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            return nil
        }

        let exif = (props[kCGImagePropertyExifDictionary as String] as? [String: Any]) ?? [:]
        let tiff = (props[kCGImagePropertyTIFFDictionary as String] as? [String: Any]) ?? [:]

        var data = ExifData()
        data.pixelWidth  = props[kCGImagePropertyPixelWidth as String]  as? Int
        data.pixelHeight = props[kCGImagePropertyPixelHeight as String] as? Int
        data.camera = (tiff[kCGImagePropertyTIFFModel as String] as? String)
            ?? (tiff[kCGImagePropertyTIFFMake as String] as? String)
        data.lens = exif[kCGImagePropertyExifLensModel as String] as? String
        if let isoArray = exif[kCGImagePropertyExifISOSpeedRatings as String] as? [Int],
           let first = isoArray.first {
            data.iso = first
        }
        if let raw = exif[kCGImagePropertyExifDateTimeOriginal as String] as? String {
            data.captureTime = Self.parseExifDate(raw)
        }
        return data
    }

    /// EXIF date format is "yyyy:MM:dd HH:mm:ss" in the camera's local time
    /// without zone info. Treat as UTC for fingerprinting purposes; UI can
    /// re-interpret with the source folder's location later.
    static func parseExifDate(_ raw: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: raw)
    }
}
