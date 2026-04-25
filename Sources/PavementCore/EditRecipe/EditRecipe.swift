import Foundation

public struct EditRecipe: Equatable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var source: RecipeSource
    public var createdAt: Date
    public var modifiedAt: Date
    public var operations: Operations
    public var ai: AIMetadata

    /// User-set star rating, 0..5. 0 = unrated. Persists in the sidecar so
    /// favorites survive across sessions.
    public var rating: Int

    /// Optional 3D LUT applied as the final color step. Set when the user
    /// applies a Style that carries a LUT (imported .cube file). Embedded
    /// in the sidecar so a photo's look is portable; sidecars only grow
    /// when a LUT is actually in use.
    public var lut: LUTData?

    /// Unknown top-level keys preserved on round-trip so a sidecar written by a
    /// future Pavement build (with new top-level fields) does not lose data
    /// when an older build loads, edits a known field, and re-saves it.
    public var unknownKeys: [String: JSONValue]

    public init(
        schemaVersion: Int = currentSchemaVersion,
        source: RecipeSource = .init(),
        createdAt: Date = EditRecipe.now(),
        modifiedAt: Date = EditRecipe.now(),
        operations: Operations = .init(),
        ai: AIMetadata = .init(),
        rating: Int = 0,
        lut: LUTData? = nil,
        unknownKeys: [String: JSONValue] = [:]
    ) {
        self.schemaVersion = schemaVersion
        self.source = source
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.operations = operations
        self.ai = ai
        self.rating = rating
        self.lut = lut
        self.unknownKeys = unknownKeys
    }

    /// Current time at whole-second precision. The JSON sidecar serializes dates
    /// without fractional seconds (matching the PLAN.md schema example), so any
    /// Date stored in a recipe should be rounded here to keep encode/decode
    /// round-trips lossless.
    public static func now() -> Date {
        Date(timeIntervalSinceReferenceDate: Date().timeIntervalSinceReferenceDate.rounded())
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

extension EditRecipe: Codable {
    private static let knownKeys: Set<String> = [
        "schemaVersion", "source", "createdAt", "modifiedAt", "operations", "ai", "rating", "lut"
    ]

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: AnyCodingKey.self)

        self.schemaVersion = try container.decode(Int.self, forKey: AnyCodingKey("schemaVersion"))
        self.source        = try container.decode(RecipeSource.self, forKey: AnyCodingKey("source"))
        self.createdAt     = try container.decode(Date.self, forKey: AnyCodingKey("createdAt"))
        self.modifiedAt    = try container.decode(Date.self, forKey: AnyCodingKey("modifiedAt"))
        self.operations    = try container.decode(Operations.self, forKey: AnyCodingKey("operations"))
        self.ai            = try container.decode(AIMetadata.self, forKey: AnyCodingKey("ai"))
        self.rating        = (try? container.decodeIfPresent(Int.self, forKey: AnyCodingKey("rating"))) ?? 0
        self.lut           = try? container.decodeIfPresent(LUTData.self, forKey: AnyCodingKey("lut"))

        var captured: [String: JSONValue] = [:]
        for key in container.allKeys where !Self.knownKeys.contains(key.stringValue) {
            captured[key.stringValue] = try container.decode(JSONValue.self, forKey: key)
        }
        self.unknownKeys = captured
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: AnyCodingKey.self)
        try container.encode(schemaVersion, forKey: AnyCodingKey("schemaVersion"))
        try container.encode(source,        forKey: AnyCodingKey("source"))
        try container.encode(createdAt,     forKey: AnyCodingKey("createdAt"))
        try container.encode(modifiedAt,    forKey: AnyCodingKey("modifiedAt"))
        try container.encode(operations,    forKey: AnyCodingKey("operations"))
        try container.encode(ai,            forKey: AnyCodingKey("ai"))
        try container.encode(rating,        forKey: AnyCodingKey("rating"))
        if let lut {
            try container.encode(lut, forKey: AnyCodingKey("lut"))
        }

        for (rawKey, value) in unknownKeys {
            try container.encode(value, forKey: AnyCodingKey(rawKey))
        }
    }
}
