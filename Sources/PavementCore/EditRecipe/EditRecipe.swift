import Foundation

public struct EditRecipe: Codable, Equatable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var source: RecipeSource
    public var createdAt: Date
    public var modifiedAt: Date
    public var operations: Operations
    public var ai: AIMetadata

    /// Current time at whole-second precision. The JSON sidecar serializes dates
    /// without fractional seconds (matching the PLAN.md schema example), so any
    /// Date stored in a recipe should be rounded here to keep encode/decode
    /// round-trips lossless.
    public static func now() -> Date {
        Date(timeIntervalSinceReferenceDate: Date().timeIntervalSinceReferenceDate.rounded())
    }

    public init(
        schemaVersion: Int = currentSchemaVersion,
        source: RecipeSource = .init(),
        createdAt: Date = EditRecipe.now(),
        modifiedAt: Date = EditRecipe.now(),
        operations: Operations = .init(),
        ai: AIMetadata = .init()
    ) {
        self.schemaVersion = schemaVersion
        self.source = source
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.operations = operations
        self.ai = ai
    }

    public static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    public static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
