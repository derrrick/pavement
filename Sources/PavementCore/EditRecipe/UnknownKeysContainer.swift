import Foundation

/// Type-erased JSON value used to preserve unknown top-level keys across
/// schema versions on round-trip.
public enum JSONValue: Codable, Equatable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
            return
        }
        if let b = try? container.decode(Bool.self) {
            self = .bool(b); return
        }
        if let i = try? container.decode(Int.self) {
            self = .int(i); return
        }
        if let d = try? container.decode(Double.self) {
            self = .double(d); return
        }
        if let s = try? container.decode(String.self) {
            self = .string(s); return
        }
        if let a = try? container.decode([JSONValue].self) {
            self = .array(a); return
        }
        if let o = try? container.decode([String: JSONValue].self) {
            self = .object(o); return
        }
        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Unsupported JSON value"
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:               try container.encodeNil()
        case .bool(let b):        try container.encode(b)
        case .int(let i):         try container.encode(i)
        case .double(let d):      try container.encode(d)
        case .string(let s):      try container.encode(s)
        case .array(let a):       try container.encode(a)
        case .object(let o):      try container.encode(o)
        }
    }
}

/// CodingKey that accepts any string. Used by EditRecipe to enumerate keys
/// at decode time and capture unknown ones into `unknownKeys`.
public struct AnyCodingKey: CodingKey {
    public var stringValue: String
    public var intValue: Int?

    public init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    public init?(intValue: Int) {
        self.intValue = intValue
        self.stringValue = String(intValue)
    }

    public init(_ raw: String) {
        self.stringValue = raw
        self.intValue = nil
    }
}
