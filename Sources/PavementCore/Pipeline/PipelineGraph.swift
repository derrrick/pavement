import Foundation
import CoreImage

/// Composes filters in PLAN.md §4 order. Stages not yet implemented are
/// skipped; their fields on the recipe are no-ops until lit up.
public struct PipelineGraph {
    public init() {}

    public func apply(_ recipe: EditRecipe, to image: CIImage) -> CIImage {
        var img = image

        // §4 step 2: Lens correction. The auto/EXIF path runs inside the
        // RAW decoder via CachedDecode; this stage is a placeholder for
        // future custom strengths and Lensfun.
        img = LensCorrectionFilter().apply(image: img, op: recipe.operations.lensCorrection)
        // §4 step 3: White balance.
        img = WhiteBalanceFilter().apply(image: img, op: recipe.operations.whiteBalance)

        // §4 step 4: Highlight reconstruction — deferred (CIRAWFilter handles some).
        // §4 step 5: Exposure.
        img = ExposureFilter().apply(image: img, op: recipe.operations.exposure)

        // §4 step 6: Tone controls (contrast/highlights/shadows; whites/blacks via curve).
        img = ToneFilter().apply(image: img, op: recipe.operations.tone)

        // §4 step 7: Tone curve.
        img = ToneCurveFilter().apply(image: img, op: recipe.operations.toneCurve)
        // Global color (hue, saturation, vibrance, luminance) sits between
        // the curve and per-band HSL so band tweaks operate on the
        // already-colour-graded image.
        img = ColorAdjustFilter().apply(image: img, op: recipe.operations.color)
        // §4 step 8: HSL (per-band).
        img = HSLFilter().apply(image: img, op: recipe.operations.hsl)
        // §4 step 9: Color grading.
        img = ColorGradingFilter().apply(image: img, op: recipe.operations.colorGrading)
        // §4 step 10: B&W — Phase 6.
        // §4 step 11: Detail (sharpening + noise reduction).
        img = DetailFilter().apply(image: img, op: recipe.operations.detail)
        // Final color "look" pass — imported LUT (.cube via Style). Runs
        // BEFORE grain so the grain stays monochrome and isn't re-tinted
        // by the LUT.
        img = LUTFilter().apply(image: img, lut: recipe.lut)
        // §4 step 12: Effects — grain (luminance-weighted, monochrome).
        img = GrainFilter().apply(image: img, op: recipe.operations.grain)
        // §4 step 13: Crop / rotate.
        img = CropFilter().apply(image: img, op: recipe.operations.crop)

        return img
    }
}
