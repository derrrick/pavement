import Foundation

/// Numeric range enforcement for every field in PLAN.md §5. Used by the UI
/// when binding sliders, by the AI ingestion path (Phase 5), and by manual
/// recipe editing in pavement-cli.
public enum Clamping {
    @inline(__always)
    public static func clamp<T: Comparable>(_ value: T, to range: ClosedRange<T>) -> T {
        min(max(value, range.lowerBound), range.upperBound)
    }

    public enum Range {
        public static let exposureEV: ClosedRange<Double> = -5.0...5.0
        public static let temperature: ClosedRange<Int> = 2000...50000
        public static let tint: ClosedRange<Int> = -150...150
        public static let signedHundred: ClosedRange<Int> = -100...100
        public static let unsignedHundred: ClosedRange<Int> = 0...100
        public static let highlightRecovery: ClosedRange<Int> = 0...100
        public static let sharpAmount: ClosedRange<Int> = 0...150
        public static let sharpRadius: ClosedRange<Double> = 0.5...3.0
        public static let hue: ClosedRange<Int> = 0...360
        public static let cropRotation: ClosedRange<Double> = -45.0...45.0
        public static let normalized: ClosedRange<Double> = 0.0...1.0
        public static let lensStrength: ClosedRange<Double> = 0.0...1.0
    }

    public static func clampInPlace(_ recipe: inout EditRecipe) {
        clampCrop(&recipe.operations.crop)
        clampLens(&recipe.operations.lensCorrection)
        clampWhiteBalance(&recipe.operations.whiteBalance)
        recipe.operations.exposure.ev = clamp(recipe.operations.exposure.ev, to: Range.exposureEV)
        clampTone(&recipe.operations.tone)
        clampHSL(&recipe.operations.hsl)
        clampGrading(&recipe.operations.colorGrading)
        clampDetail(&recipe.operations.detail)
        clampGrain(&recipe.operations.grain)
        clampVignette(&recipe.operations.vignette)
    }

    public static func clamped(_ recipe: EditRecipe) -> EditRecipe {
        var copy = recipe
        clampInPlace(&copy)
        return copy
    }

    // MARK: - Per-operation clampers

    private static func clampCrop(_ op: inout CropOp) {
        op.x = clamp(op.x, to: Range.normalized)
        op.y = clamp(op.y, to: Range.normalized)
        op.w = clamp(op.w, to: Range.normalized)
        op.h = clamp(op.h, to: Range.normalized)
        op.rotation = clamp(op.rotation, to: Range.cropRotation)
    }

    private static func clampLens(_ op: inout LensCorrectionOp) {
        op.distortion = clamp(op.distortion, to: Range.lensStrength)
        op.ca         = clamp(op.ca,         to: Range.lensStrength)
        op.vignette   = clamp(op.vignette,   to: Range.lensStrength)
    }

    private static func clampWhiteBalance(_ op: inout WhiteBalanceOp) {
        op.temp = clamp(op.temp, to: Range.temperature)
        op.tint = clamp(op.tint, to: Range.tint)
    }

    private static func clampTone(_ op: inout ToneOp) {
        op.contrast          = clamp(op.contrast,          to: Range.signedHundred)
        op.highlights        = clamp(op.highlights,        to: Range.signedHundred)
        op.shadows           = clamp(op.shadows,           to: Range.signedHundred)
        op.whites            = clamp(op.whites,            to: Range.signedHundred)
        op.blacks            = clamp(op.blacks,            to: Range.signedHundred)
        op.highlightRecovery = clamp(op.highlightRecovery, to: Range.highlightRecovery)
    }

    private static func clampHSL(_ op: inout HSLOp) {
        clampBand(&op.red);    clampBand(&op.orange); clampBand(&op.yellow)
        clampBand(&op.green);  clampBand(&op.aqua);   clampBand(&op.blue)
        clampBand(&op.purple); clampBand(&op.magenta)
    }

    private static func clampBand(_ band: inout HSLBand) {
        band.h = clamp(band.h, to: Range.signedHundred)
        band.s = clamp(band.s, to: Range.signedHundred)
        band.l = clamp(band.l, to: Range.signedHundred)
    }

    private static func clampGrading(_ op: inout ColorGradingOp) {
        clampWheel(&op.shadows); clampWheel(&op.midtones)
        clampWheel(&op.highlights); clampWheel(&op.global)
        op.blending = clamp(op.blending, to: Range.unsignedHundred)
        op.balance  = clamp(op.balance,  to: Range.signedHundred)
    }

    private static func clampWheel(_ wheel: inout GradingWheel) {
        wheel.hue = clamp(wheel.hue, to: Range.hue)
        wheel.sat = clamp(wheel.sat, to: Range.signedHundred)
        wheel.lum = clamp(wheel.lum, to: Range.signedHundred)
    }

    private static func clampDetail(_ op: inout DetailOp) {
        op.sharpAmount  = clamp(op.sharpAmount,  to: Range.sharpAmount)
        op.sharpRadius  = clamp(op.sharpRadius,  to: Range.sharpRadius)
        op.sharpMasking = clamp(op.sharpMasking, to: Range.unsignedHundred)
        op.noiseLuma    = clamp(op.noiseLuma,    to: Range.unsignedHundred)
        op.noiseColor   = clamp(op.noiseColor,   to: Range.unsignedHundred)
    }

    private static func clampGrain(_ op: inout GrainOp) {
        op.amount    = clamp(op.amount,    to: Range.unsignedHundred)
        op.size      = clamp(op.size,      to: Range.unsignedHundred)
        op.roughness = clamp(op.roughness, to: Range.unsignedHundred)
    }

    private static func clampVignette(_ op: inout VignetteOp) {
        op.amount    = clamp(op.amount,    to: Range.signedHundred)
        op.midpoint  = clamp(op.midpoint,  to: Range.unsignedHundred)
        op.feather   = clamp(op.feather,   to: Range.unsignedHundred)
        op.roundness = clamp(op.roundness, to: Range.signedHundred)
    }
}
