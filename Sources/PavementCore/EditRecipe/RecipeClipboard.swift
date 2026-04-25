import Foundation

/// Process-wide clipboard for edit operations. "Copy Settings" snapshots
/// the current recipe's operation blocks; "Paste Settings" applies them
/// to another document. Per-section toggles (kept here so paste can be
/// selective) live on the snapshot.
@MainActor
public final class RecipeClipboard: ObservableObject {
    public static let shared = RecipeClipboard()

    public private(set) var snapshot: Snapshot?

    public struct Snapshot: Equatable {
        public let operations: Operations
        public let lut: LUTData?
        public let capturedAt: Date

        public init(operations: Operations, lut: LUTData?, capturedAt: Date = .now) {
            self.operations = operations
            self.lut = lut
            self.capturedAt = capturedAt
        }
    }

    private init() {}

    public func copy(from recipe: EditRecipe) {
        snapshot = Snapshot(
            operations: recipe.operations,
            lut: recipe.lut
        )
        objectWillChange.send()
    }

    public func paste(into recipe: inout EditRecipe, exclusions: Set<OperationKind> = []) {
        guard let snap = snapshot else { return }
        var ops = recipe.operations

        if !exclusions.contains(.crop)           { ops.crop           = snap.operations.crop }
        if !exclusions.contains(.lensCorrection) { ops.lensCorrection = snap.operations.lensCorrection }
        if !exclusions.contains(.whiteBalance)   { ops.whiteBalance   = snap.operations.whiteBalance }
        if !exclusions.contains(.exposure)       { ops.exposure       = snap.operations.exposure }
        if !exclusions.contains(.tone)           { ops.tone           = snap.operations.tone }
        if !exclusions.contains(.toneCurve)      { ops.toneCurve      = snap.operations.toneCurve }
        if !exclusions.contains(.color)          { ops.color          = snap.operations.color }
        if !exclusions.contains(.hsl)            { ops.hsl            = snap.operations.hsl }
        if !exclusions.contains(.colorGrading)   { ops.colorGrading   = snap.operations.colorGrading }
        if !exclusions.contains(.bw)             { ops.bw             = snap.operations.bw }
        if !exclusions.contains(.detail)         { ops.detail         = snap.operations.detail }
        if !exclusions.contains(.grain)          { ops.grain          = snap.operations.grain }
        if !exclusions.contains(.vignette)       { ops.vignette       = snap.operations.vignette }

        recipe.operations = ops
        recipe.lut = snap.lut
        recipe.modifiedAt = EditRecipe.now()
    }

    public var hasContent: Bool { snapshot != nil }
}
