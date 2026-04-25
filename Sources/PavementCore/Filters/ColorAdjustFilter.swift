import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins

/// Global color adjustments: hue rotation, saturation, vibrance, luminance.
/// Mirrors what each per-band HSL slider does, but applied uniformly across
/// every pixel. Vibrance smart-saturates muted colors more than already
/// saturated ones (Apple's CIVibrance behavior).
public struct ColorAdjustFilter {
    public init() {}

    public func apply(image: CIImage, op: ColorOp) -> CIImage {
        var img = image

        if op.hue != 0 {
            let f = CIFilter.hueAdjust()
            f.inputImage = img
            f.angle = Float(op.hue) * .pi / 180
            img = f.outputImage ?? img
        }

        if op.saturation != 0 || op.luminance != 0 {
            let f = CIFilter.colorControls()
            f.inputImage = img
            // -100..100 → 0..2 (1.0 = identity)
            f.saturation = 1.0 + Float(op.saturation) / 100.0
            // -100..100 → -0.5..0.5 additive offset
            f.brightness = Float(op.luminance) / 200.0
            f.contrast = 1.0
            img = f.outputImage ?? img
        }

        if op.vibrance != 0 {
            let f = CIFilter.vibrance()
            f.inputImage = img
            f.amount = Float(op.vibrance) / 100.0
            img = f.outputImage ?? img
        }

        return img
    }

    public static func isIdentity(_ op: ColorOp) -> Bool {
        op.hue == 0 && op.saturation == 0 && op.vibrance == 0 && op.luminance == 0
    }
}
