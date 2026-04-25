import Foundation

public struct RecipeSource: Codable, Equatable {
    public var path: String
    public var fingerprint: String
    public var camera: String?
    public var lens: String?
    public var iso: Int?
    public var captureTime: Date?

    public init(
        path: String = "",
        fingerprint: String = "",
        camera: String? = nil,
        lens: String? = nil,
        iso: Int? = nil,
        captureTime: Date? = nil
    ) {
        self.path = path
        self.fingerprint = fingerprint
        self.camera = camera
        self.lens = lens
        self.iso = iso
        self.captureTime = captureTime
    }
}
