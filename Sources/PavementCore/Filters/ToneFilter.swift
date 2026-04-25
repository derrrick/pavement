import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins

/// Parametric tone control. Phase 2 implements contrast + highlights/shadows
/// via Apple's built-in filters; whites/blacks/highlightRecovery land in
/// later phases (whites/blacks via the per-channel tone curve, recovery via
/// the RAW-decode stage).
public struct ToneFilter {
    public init() {}

    public func apply(image: CIImage, op: ToneOp) -> CIImage {
        var img = image

        if op.highlights != 0 || op.shadows != 0 {
            let f = CIFilter.highlightShadowAdjust()
            f.inputImage = img
            // Apple's filter expects highlight in 0...1 and shadow in 0...1.
            // Map -100..100 -> -1..1 (negative pulls highlights down,
            // positive lifts shadows up).
            f.highlightAmount = Float(op.highlights) / 100.0
            f.shadowAmount    = Float(op.shadows)    / 100.0
            img = f.outputImage ?? img
        }

        if op.contrast != 0 {
            let f = CIFilter.colorControls()
            f.inputImage = img
            // CIColorControls inputContrast: 1.0 = identity. Map -100..100
            // to 0.5..1.5 (half-contrast to 1.5x contrast).
            f.contrast = 1.0 + Float(op.contrast) / 200.0
            img = f.outputImage ?? img
        }

        return img
    }
}
