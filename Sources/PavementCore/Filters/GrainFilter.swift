import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins

/// Six classic film/digital grain types, applied uniformly to the
/// entire image. Per-pixel monochrome noise via `CIRandomGenerator`
/// (full image resolution, GPU-fast, no tiling artifacts), shaped per
/// type by Gaussian/motion blur + contrast.
///
/// Deliberately simple. No luma weighting — grain applies to every
/// pixel including highlights and shadows so the effect is visible
/// across the entire frame.
public struct GrainFilter {
    public init() {}

    public func apply(image: CIImage, op: GrainOp) -> CIImage {
        guard op.amount > 0 else { return image }
        let extent = image.extent
        guard extent.width.isFinite, extent.height.isFinite,
              extent.width > 0, extent.height > 0 else { return image }

        // Per-pixel noise at native image resolution.
        let baseNoise = (CIFilter.randomGenerator().outputImage ?? CIImage(color: .gray))
            .cropped(to: extent)
            // Monochrome: one channel value duplicated to R, G, B so we
            // get pure luma grain (no color speckle).
            .applyingFilter("CIColorMonochrome", parameters: [
                kCIInputColorKey: CIColor(red: 0.5, green: 0.5, blue: 0.5),
                kCIInputIntensityKey: 1.0
            ])

        // Per-type shape (blur radius + contrast).
        let shaped = shape(baseNoise, op: op)

        // Center around 0, scale by amount, add to image. Grain ranges
        // in [-i, +i] around each pixel — brightens AND darkens.
        let intensity = CGFloat(op.amount) / 100.0 * 0.55
        let signed = shaped.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: intensity * 2, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: intensity * 2, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: intensity * 2, w: 0),
            "inputBiasVector": CIVector(x: -intensity, y: -intensity, z: -intensity, w: 0)
        ])

        return signed.applyingFilter("CIAdditionCompositing", parameters: [
            kCIInputBackgroundImageKey: image
        ])
    }

    public static func isIdentity(_ op: GrainOp) -> Bool {
        op.amount == 0
    }

    // MARK: - Per-type shaping

    /// Per-type blur + contrast. The grain looks distinctly different
    /// because the BLUR RADIUS and CONTRAST settings define the
    /// crystalline character — fine vs chunky, sharp vs diffuse,
    /// neutral vs gritty.
    private func shape(_ noise: CIImage, op: GrainOp) -> CIImage {
        let size = CGFloat(op.size) / 100        // 0..1
        let roughness = CGFloat(op.roughness) / 100  // 0..1

        switch op.type {

        case GrainOp.typeFine:
            // Modern digital: tiny softening + light contrast lift.
            // The grain is per-pixel uniform with crisp edges.
            let blur = max(0.3, 0.3 + size * 0.6)        // 0.3..0.9 px
            return noise
                .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: blur])
                .cropped(to: noise.extent)
                .applyingFilter("CIColorControls", parameters: [
                    kCIInputContrastKey: 1.3 + roughness * 0.5,
                    kCIInputSaturationKey: 0.0
                ])

        case GrainOp.typeCubic:
            // T-MAX-style: small but well-defined crystals. Slightly
            // larger than Fine, with stronger contrast for the crisp
            // crystal-edge look.
            let blur = max(0.5, 0.6 + size * 1.4)        // 0.6..2.0 px
            return noise
                .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: blur])
                .cropped(to: noise.extent)
                .applyingFilter("CIColorControls", parameters: [
                    kCIInputContrastKey: 1.8 + roughness * 0.7,
                    kCIInputSaturationKey: 0.0
                ])

        case GrainOp.typeTabular:
            // Platelet shape via horizontal motion blur — visibly
            // anisotropic, slightly elongated streaks.
            let streak = max(1.5, 2.0 + size * 5)        // 2..7 px
            return noise
                .applyingFilter("CIMotionBlur", parameters: [
                    kCIInputRadiusKey: streak,
                    kCIInputAngleKey: 0.0
                ])
                .cropped(to: noise.extent)
                .applyingFilter("CIColorControls", parameters: [
                    kCIInputContrastKey: 1.5 + roughness * 0.6,
                    kCIInputSaturationKey: 0.0
                ])

        case GrainOp.typeSilverRich:
            // Heavier silver content: medium-large grain with high
            // contrast for the dense, deeply-textured Ilford look.
            let blur = max(0.7, 0.8 + size * 1.6)        // 0.8..2.4 px
            return noise
                .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: blur])
                .cropped(to: noise.extent)
                .applyingFilter("CIColorControls", parameters: [
                    kCIInputContrastKey: 2.1 + roughness * 0.8,
                    kCIInputSaturationKey: 0.0
                ])

        case GrainOp.typeSoft:
            // Diffuse portrait grain: heavy Gaussian blur dilutes the
            // grain into atmospheric texture rather than crystals.
            let blur = max(2.5, 3.0 + size * 6)          // 3..9 px
            return noise
                .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: blur])
                .cropped(to: noise.extent)
                .applyingFilter("CIColorControls", parameters: [
                    kCIInputContrastKey: 0.9 + roughness * 0.4,
                    kCIInputSaturationKey: 0.0
                ])

        case GrainOp.typeHarsh:
            // Pushed film: extreme contrast pushes grain values toward
            // the extremes — gritty, binary-feeling clumps.
            let blur = max(0.4, 0.5 + size * 1.2)        // 0.5..1.7 px
            return noise
                .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: blur])
                .cropped(to: noise.extent)
                .applyingFilter("CIColorControls", parameters: [
                    kCIInputContrastKey: 3.0 + roughness * 1.5,
                    kCIInputBrightnessKey: -0.05,
                    kCIInputSaturationKey: 0.0
                ])

        default:
            return noise
        }
    }
}
