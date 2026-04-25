import Foundation

public struct AIMetadata: Codable, Equatable {
    public var lastPrompt: String?
    public var lastReferenceFingerprints: [String]?
    public var lastModel: String?
    public var lastInvokedAt: Date?
    public var rationale: String?

    public init(
        lastPrompt: String? = nil,
        lastReferenceFingerprints: [String]? = nil,
        lastModel: String? = nil,
        lastInvokedAt: Date? = nil,
        rationale: String? = nil
    ) {
        self.lastPrompt = lastPrompt
        self.lastReferenceFingerprints = lastReferenceFingerprints
        self.lastModel = lastModel
        self.lastInvokedAt = lastInvokedAt
        self.rationale = rationale
    }
}
