import Foundation

/// User-created or imported style. Sits alongside `Preset` (built-in
/// looks): styles are mutable, persisted to disk, and can declare per-
/// section exclusions so applying a style doesn't overwrite per-image
/// crops or white balance unless the user opts in.
public struct Style: Identifiable, Codable, Equatable {
    public var id: String
    public var name: String
    public var category: String          // "User", "Lightroom", "LUT", etc.
    public var description: String
    public var operations: Operations
    public var exclusions: Set<OperationKind>
    public var recommendedOpacity: Double
    public var createdAt: Date
    /// Optional 3D LUT applied as a final pass after operations. Lets
    /// imported .cube LUTs ride alongside parametric adjustments in a
    /// single style.
    public var lut: LUTData?

    public init(
        id: String = UUID().uuidString,
        name: String,
        category: String = "User",
        description: String = "",
        operations: Operations,
        exclusions: Set<OperationKind> = Style.defaultExclusions,
        recommendedOpacity: Double = 1.0,
        createdAt: Date = EditRecipe.now(),
        lut: LUTData? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.description = description
        self.operations = operations
        self.exclusions = exclusions
        self.recommendedOpacity = Clamping.clamp(recommendedOpacity, to: 0.0...1.0)
        self.createdAt = createdAt
        self.lut = lut
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, category, description, operations, exclusions
        case recommendedOpacity, createdAt, lut
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(String.self, forKey: .id)
        self.name = try c.decode(String.self, forKey: .name)
        self.category = (try? c.decodeIfPresent(String.self, forKey: .category)) ?? "User"
        self.description = (try? c.decodeIfPresent(String.self, forKey: .description)) ?? ""
        self.operations = try c.decode(Operations.self, forKey: .operations)
        self.exclusions = (try? c.decodeIfPresent(Set<OperationKind>.self, forKey: .exclusions)) ?? Style.defaultExclusions
        let opacity = (try? c.decodeIfPresent(Double.self, forKey: .recommendedOpacity)) ?? 1.0
        self.recommendedOpacity = Clamping.clamp(opacity, to: 0.0...1.0)
        self.createdAt = (try? c.decodeIfPresent(Date.self, forKey: .createdAt)) ?? EditRecipe.now()
        self.lut = try? c.decodeIfPresent(LUTData.self, forKey: .lut)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(category, forKey: .category)
        try c.encode(description, forKey: .description)
        try c.encode(operations, forKey: .operations)
        try c.encode(exclusions, forKey: .exclusions)
        try c.encode(recommendedOpacity, forKey: .recommendedOpacity)
        try c.encode(createdAt, forKey: .createdAt)
        if let lut {
            try c.encode(lut, forKey: .lut)
        }
    }

    /// Field-level exclusions a brand-new style applies by default. Crop,
    /// lens correction, and white balance are per-image and shouldn't
    /// hop around when a user shares a style; everything else does.
    public static let defaultExclusions: Set<OperationKind> = [
        .crop, .lensCorrection, .whiteBalance
    ]
}

/// Identifies a single operation block on Operations. Used by Style
/// exclusions and by future stacked-style logic.
public enum OperationKind: String, Codable, CaseIterable, Hashable {
    case crop
    case lensCorrection
    case whiteBalance
    case exposure
    case tone
    case toneCurve
    case color
    case hsl
    case colorGrading
    case bw
    case detail
    case grain
    case vignette

    public var displayName: String {
        switch self {
        case .crop:           return "Crop"
        case .lensCorrection: return "Lens Correction"
        case .whiteBalance:   return "White Balance"
        case .exposure:       return "Exposure"
        case .tone:           return "Tone"
        case .toneCurve:      return "Tone Curve"
        case .color:          return "Color"
        case .hsl:            return "HSL"
        case .colorGrading:   return "Color Balance"
        case .bw:             return "B&W"
        case .detail:         return "Detail"
        case .grain:          return "Grain"
        case .vignette:       return "Vignette"
        }
    }
}

/// 3D color cube LUT, RGBA-float layout matching CIColorCube. Cube is
/// stored at its native dimension (typically 16, 17, 32, or 33).
public struct LUTData: Codable, Equatable {
    public var dimension: Int
    public var data: Data
    public var name: String

    public init(dimension: Int, data: Data, name: String) {
        self.dimension = dimension
        self.data = data
        self.name = name
    }
}

extension EditRecipe {
    /// Apply a style by overwriting each non-excluded operation block.
    /// Crop / lens correction / white balance defaults to excluded so
    /// per-image properties survive. Modifies modifiedAt so the sidecar
    /// autosave fires.
    public mutating func apply(style: Style) {
        apply(style: style, amount: style.recommendedOpacity)
    }

    /// Apply a style as an editable recipe stack at the style's requested
    /// intensity. LUT-only styles keep their LUT at full strength because
    /// the current renderer has no LUT opacity stage yet.
    public mutating func apply(style: Style, amount: Double) {
        let scaled = style.operations.scaled(by: amount)
        var ops = operations

        if !style.exclusions.contains(.exposure)     { ops.exposure     = scaled.exposure }
        if !style.exclusions.contains(.tone)         { ops.tone         = scaled.tone }
        if !style.exclusions.contains(.toneCurve)    { ops.toneCurve    = scaled.toneCurve }
        if !style.exclusions.contains(.color)        { ops.color        = scaled.color }
        if !style.exclusions.contains(.hsl)          { ops.hsl          = scaled.hsl }
        if !style.exclusions.contains(.colorGrading) { ops.colorGrading = scaled.colorGrading }
        if !style.exclusions.contains(.bw)           { ops.bw           = scaled.bw }
        if !style.exclusions.contains(.detail)       { ops.detail       = scaled.detail }
        if !style.exclusions.contains(.grain)        { ops.grain        = scaled.grain }
        if !style.exclusions.contains(.vignette)     { ops.vignette     = scaled.vignette }

        if !style.exclusions.contains(.crop)           { ops.crop           = scaled.crop }
        if !style.exclusions.contains(.lensCorrection) { ops.lensCorrection = scaled.lensCorrection }
        if !style.exclusions.contains(.whiteBalance)   { ops.whiteBalance   = scaled.whiteBalance }

        operations = ops
        lut = style.lut
        modifiedAt = EditRecipe.now()
    }
}
