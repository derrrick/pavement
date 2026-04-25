import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins

/// Noise reduction + sharpening, driven by the recipe's DetailOp.
/// Sharpening runs first so the unsharp mask sees the source's detail,
/// then noise reduction smooths the result.
public struct DetailFilter {
    public init() {}

    public func apply(image: CIImage, op: DetailOp) -> CIImage {
        var img = image

        if op.sharpAmount > 0 {
            let f = CIFilter.unsharpMask()
            f.inputImage = img
            // 0..150 → intensity 0..1.5
            f.intensity = Float(op.sharpAmount) / 100.0
            f.radius = Float(op.sharpRadius)
            img = f.outputImage ?? img
        }

        if op.noiseLuma > 0 || op.noiseColor > 0 {
            let f = CIFilter.noiseReduction()
            f.inputImage = img
            // 0..100 → noiseLevel 0..0.06
            // Bias toward the larger of the two so the user sees a single
            // noise reduction effect; precise luma/color split lives in
            // a future bilateral pass.
            let amount = max(Float(op.noiseLuma), Float(op.noiseColor)) / 100.0
            f.noiseLevel = amount * 0.06
            // Sharpness 0..1: 1 keeps detail, 0 blurs heavily. Higher noise
            // levels naturally need lower sharpness to actually smooth.
            f.sharpness = max(0, 1.0 - amount * 0.6)
            img = f.outputImage ?? img
        }

        return img
    }

    /// True only when every detail field is at its no-effect value.
    /// Note: DetailOp's default sharpAmount is 30 per PLAN.md §5, so a
    /// fresh recipe will apply mild sharpening — same baseline behavior
    /// as Lightroom's default sharpening of 25/40.
    public static func isIdentity(_ op: DetailOp) -> Bool {
        op.sharpAmount == 0 && op.noiseLuma == 0 && op.noiseColor == 0
    }
}
