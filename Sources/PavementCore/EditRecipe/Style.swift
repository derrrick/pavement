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
        createdAt: Date = EditRecipe.now(),
        lut: LUTData? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.description = description
        self.operations = operations
        self.exclusions = exclusions
        self.createdAt = createdAt
        self.lut = lut
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
        var ops = operations

        if !style.exclusions.contains(.exposure)     { ops.exposure     = style.operations.exposure }
        if !style.exclusions.contains(.tone)         { ops.tone         = style.operations.tone }
        if !style.exclusions.contains(.toneCurve)    { ops.toneCurve    = style.operations.toneCurve }
        if !style.exclusions.contains(.color)        { ops.color        = style.operations.color }
        if !style.exclusions.contains(.hsl)          { ops.hsl          = style.operations.hsl }
        if !style.exclusions.contains(.colorGrading) { ops.colorGrading = style.operations.colorGrading }
        if !style.exclusions.contains(.bw)           { ops.bw           = style.operations.bw }
        if !style.exclusions.contains(.detail)       { ops.detail       = style.operations.detail }
        if !style.exclusions.contains(.grain)        { ops.grain        = style.operations.grain }
        if !style.exclusions.contains(.vignette)     { ops.vignette     = style.operations.vignette }

        if !style.exclusions.contains(.crop)           { ops.crop           = style.operations.crop }
        if !style.exclusions.contains(.lensCorrection) { ops.lensCorrection = style.operations.lensCorrection }
        if !style.exclusions.contains(.whiteBalance)   { ops.whiteBalance   = style.operations.whiteBalance }

        operations = ops
        lut = style.lut
        modifiedAt = EditRecipe.now()
    }
}
