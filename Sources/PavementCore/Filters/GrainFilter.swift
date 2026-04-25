import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins

/// Procedural film grain in five types inspired by Capture One's grain
/// engine: Cubic (classic silver halide), Tabular (modern T-grain),
/// Newsprint (ordered halftone), Soft (diffused organic), Plate
/// (wet-collodion blotchy). Built on CIRandomGenerator + per-type
/// shaping filters; all output goes through CIAdditionCompositing so
/// grain brightens AND darkens pixels rather than overlaying as fog.
public struct GrainFilter {
    public init() {}

    public func apply(image: CIImage, op: GrainOp) -> CIImage {
        guard op.amount > 0 else { return image }
        let extent = image.extent
        guard extent.width.isFinite, extent.height.isFinite else { return image }

        let noise = makeNoise(extent: extent, op: op)

        // Center grayscale noise around 0.5, then scale by amount, then
        // bias by -0.5 so the result is signed (pixel ± grain).
        let intensity = CGFloat(op.amount) / 100.0 * 0.45

        let signed = noise
            .applyingFilter("CIColorMonochrome", parameters: [
                kCIInputColorKey: CIColor(red: 0.5, green: 0.5, blue: 0.5),
                kCIInputIntensityKey: 1.0
            ])
            .applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: intensity, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: intensity, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: intensity, w: 0),
                "inputBiasVector": CIVector(x: -intensity / 2,
                                            y: -intensity / 2,
                                            z: -intensity / 2,
                                            w: 0)
            ])

        return signed.applyingFilter("CIAdditionCompositing", parameters: [
            kCIInputBackgroundImageKey: image
        ])
    }

    public static func isIdentity(_ op: GrainOp) -> Bool {
        op.amount == 0
    }

    // MARK: - Noise generators

    private func makeNoise(extent: CGRect, op: GrainOp) -> CIImage {
        let base = CIFilter.randomGenerator().outputImage ?? CIImage(color: .gray)
        let cropped = base.cropped(to: extent)

        // size 0..100 → blur radius 0..5 px (drives "grain size")
        let sizeRadius = Double(op.size) / 100.0 * 5.0
        // roughness 0..100 → contrast multiplier 0.5..1.5
        let roughness = 0.5 + Double(op.roughness) / 100.0

        switch op.type {
        case GrainOp.typeCubic:
            return cubic(cropped, size: sizeRadius, roughness: roughness)
        case GrainOp.typeTabular:
            return tabular(cropped, size: sizeRadius, roughness: roughness)
        case GrainOp.typeNewsprint:
            return newsprint(cropped, size: sizeRadius, roughness: roughness)
        case GrainOp.typeSilverRich:
            return silverRich(cropped, size: sizeRadius, roughness: roughness)
        case GrainOp.typeSoft:
            return soft(cropped, size: sizeRadius, roughness: roughness)
        case GrainOp.typePlate:
            return plate(cropped, size: sizeRadius, roughness: roughness)
        default:
            return cubic(cropped, size: sizeRadius, roughness: roughness)
        }
    }

    /// Classic sharp silver-halide grain.
    private func cubic(_ noise: CIImage, size: Double, roughness: Double) -> CIImage {
        let blurred = noise.applyingFilter("CIGaussianBlur", parameters: [
            kCIInputRadiusKey: max(0.3, size * 0.4)
        ])
        return blurred.applyingFilter("CIColorControls", parameters: [
            kCIInputContrastKey: 1.0 + roughness * 0.4,
            kCIInputSaturationKey: 0.0
        ])
    }

    /// T-grain: directional blur creates flatter, slightly elongated grain.
    private func tabular(_ noise: CIImage, size: Double, roughness: Double) -> CIImage {
        return noise
            .applyingFilter("CIMotionBlur", parameters: [
                kCIInputRadiusKey: max(0.5, size * 0.7),
                kCIInputAngleKey: 0.4
            ])
            .cropped(to: noise.extent)
            .applyingFilter("CIColorControls", parameters: [
                kCIInputContrastKey: 1.0 + roughness * 0.35,
                kCIInputSaturationKey: 0.0
            ])
    }

    /// Ordered halftone-like pattern. Threshold the noise so output is
    /// mostly white and black rather than smooth — reads as newsprint dots.
    private func newsprint(_ noise: CIImage, size: Double, roughness: Double) -> CIImage {
        let blurred = noise.applyingFilter("CIGaussianBlur", parameters: [
            kCIInputRadiusKey: max(0.4, size * 0.5)
        ])
        // Push to extreme contrast so values cluster near 0 and 1.
        return blurred.applyingFilter("CIColorControls", parameters: [
            kCIInputContrastKey: 3.5 + roughness * 0.5,
            kCIInputSaturationKey: 0.0,
            kCIInputBrightnessKey: -0.05
        ])
    }

    /// High-amplitude grain weighted toward darker noise — heavy silver
    /// content like Ilford Delta 3200. We just push contrast hard;
    /// luminance-aware weighting would need image luminance, deferred.
    private func silverRich(_ noise: CIImage, size: Double, roughness: Double) -> CIImage {
        return cubic(noise, size: size * 1.2, roughness: roughness * 1.4)
    }

    /// Soft, diffused organic grain — wider Gaussian.
    private func soft(_ noise: CIImage, size: Double, roughness: Double) -> CIImage {
        let blurred = noise.applyingFilter("CIGaussianBlur", parameters: [
            kCIInputRadiusKey: max(0.8, size * 1.2)
        ])
        return blurred.applyingFilter("CIColorControls", parameters: [
            kCIInputContrastKey: 0.85 + roughness * 0.2,
            kCIInputSaturationKey: 0.0
        ])
    }

    /// Wet-plate collodion: large, blotchy structures. Downsample then
    /// upsample to enlarge the grain, then blur for low-frequency look.
    private func plate(_ noise: CIImage, size: Double, roughness: Double) -> CIImage {
        let factor = 1.0 / max(2.0, 4.0 + size)
        let downscaled = noise.applyingFilter("CILanczosScaleTransform", parameters: [
            kCIInputScaleKey: factor,
            kCIInputAspectRatioKey: 1.0
        ])
        let upscaled = downscaled.applyingFilter("CILanczosScaleTransform", parameters: [
            kCIInputScaleKey: 1.0 / factor,
            kCIInputAspectRatioKey: 1.0
        ])
        return upscaled
            .cropped(to: noise.extent)
            .applyingFilter("CIColorControls", parameters: [
                kCIInputContrastKey: 1.2 + roughness * 0.3,
                kCIInputSaturationKey: 0.0
            ])
    }
}
