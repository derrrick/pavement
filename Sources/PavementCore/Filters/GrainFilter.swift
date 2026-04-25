import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins

/// Procedural film grain. Six visually distinct types that aim to feel
/// like real silver / dye grain rather than tiled noise.
///
/// Two earlier sins, now fixed:
///   1. `CIPixellate` was used for most types — it tiles the image into a
///      regular grid of cells, which the eye reads as a repeating texture
///      ("blocky" grain). Cubic / Silver Rich / Plate now use raw
///      per-pixel noise plus selective Gaussian blur instead.
///   2. The noise origin was always (0,0), so every image got the same
///      noise pattern. We now translate the noise by a per-image offset
///      derived from the image extent — different photos get visually
///      different grain, same photo stays stable across renders.
///
/// Real-film signature retained: luminance weighting via a bell-curve
/// gradient (peaks in midtones for most types, in shadows for Silver
/// Rich), so clipped extremes get ~no grain — matches what Fujifilm's
/// in-camera grain effect does.
public struct GrainFilter {
    public init() {}

    public func apply(image: CIImage, op: GrainOp) -> CIImage {
        guard op.amount > 0 else { return image }
        let extent = image.extent
        guard extent.width.isFinite, extent.height.isFinite,
              extent.width > 0, extent.height > 0 else { return image }

        let grainBase = generateGrain(extent: extent, op: op)
        let lumaMask = makeLumaMask(image: image, type: op.type)
        let weighted = grainBase.applyingFilter("CIMultiplyCompositing", parameters: [
            kCIInputBackgroundImageKey: lumaMask
        ])

        let intensity = CGFloat(op.amount) / 100.0 * 0.65
        let signed = weighted.applyingFilter("CIColorMatrix", parameters: [
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

    // MARK: - Per-image noise base

    /// Generates the per-image random noise. The noise is translated by a
    /// deterministic per-image offset (hashed from the image extent) so
    /// different sources get different patterns while a single source's
    /// grain stays stable across renders.
    private func baseNoise(extent: CGRect) -> CIImage {
        let raw = CIFilter.randomGenerator().outputImage ?? CIImage(color: .gray)

        // Pseudo-random per-image offset to break the (0,0) tile alignment.
        // Different image dimensions → different offset → distinct grain.
        let w = Int(extent.width)
        let h = Int(extent.height)
        let offsetX = CGFloat((w &* 31 &+ h &* 47) % 997)
        let offsetY = CGFloat((w &* 53 &+ h &* 71) % 991)

        return raw
            .transformed(by: CGAffineTransform(translationX: offsetX, y: offsetY))
            .cropped(to: extent)
            .applyingFilter("CIColorMonochrome", parameters: [
                kCIInputColorKey: CIColor(red: 0.5, green: 0.5, blue: 0.5),
                kCIInputIntensityKey: 1.0
            ])
    }

    // MARK: - Per-type generators

    private func generateGrain(extent: CGRect, op: GrainOp) -> CIImage {
        let noise = baseNoise(extent: extent)
        let size = CGFloat(op.size) / 100         // 0..1
        let roughness = CGFloat(op.roughness) / 100  // 0..1

        switch op.type {
        case GrainOp.typeCubic:      return cubic(noise, size: size, roughness: roughness)
        case GrainOp.typeTabular:    return tabular(noise, size: size, roughness: roughness)
        case GrainOp.typeNewsprint:  return newsprint(extent: extent, size: size, roughness: roughness)
        case GrainOp.typeSilverRich: return silverRich(noise, size: size, roughness: roughness)
        case GrainOp.typeSoft:       return soft(noise, size: size, roughness: roughness)
        case GrainOp.typePlate:      return plate(noise, size: size, roughness: roughness)
        default:                     return cubic(noise, size: size, roughness: roughness)
        }
    }

    /// **Cubic** — classic sharp silver-halide grain. Per-pixel random
    /// noise with a slight Gaussian softening; we layer a wider-blurred
    /// copy in to add organic clumping (a two-octave fBm-style blend) so
    /// the grain doesn't read as flat hash noise.
    private func cubic(_ noise: CIImage, size: CGFloat, roughness: CGFloat) -> CIImage {
        let fineRadius = max(0.4, 0.4 + size * 1.4)
        let coarseRadius = max(2.0, 2.0 + size * 6.0)

        let fine = noise
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: fineRadius])
            .cropped(to: noise.extent)

        let coarse = noise
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: coarseRadius])
            .cropped(to: noise.extent)
            .applyingFilter("CIColorMatrix", parameters: [
                // Coarse layer rides at 35% alpha so it modulates without
                // dominating — gives clumpy "developed" look.
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0.35)
            ])

        let combined = coarse
            .applyingFilter("CISourceOverCompositing", parameters: [
                kCIInputBackgroundImageKey: fine
            ])
            .cropped(to: noise.extent)

        return combined.applyingFilter("CIColorControls", parameters: [
            kCIInputContrastKey: 1.7 + roughness * 0.7,
            kCIInputSaturationKey: 0.0
        ])
    }

    /// **Tabular** — modern T-grain: heavy directional motion blur creates
    /// elongated, anisotropic streaks. Different from cubic at any size.
    private func tabular(_ noise: CIImage, size: CGFloat, roughness: CGFloat) -> CIImage {
        let streakLength = max(2.0, 2.5 + size * 9)
        return noise
            .applyingFilter("CIMotionBlur", parameters: [
                kCIInputRadiusKey: streakLength,
                kCIInputAngleKey: 0.05  // near-horizontal
            ])
            .cropped(to: noise.extent)
            .applyingFilter("CIColorControls", parameters: [
                kCIInputContrastKey: 1.4 + roughness * 0.5,
                kCIInputSaturationKey: 0.0
            ])
    }

    /// **Newsprint** — actual ordered halftone via `CIDotScreen` over a
    /// flat gray plate. Genuinely regular dots — that's the look — but
    /// distinctly NOT random noise, which is the whole point of the type.
    private func newsprint(extent: CGRect, size: CGFloat, roughness: CGFloat) -> CIImage {
        // CIDotScreen draws halftone dots whose density is driven by the
        // input image's luminance. A flat 0.5 gray gives uniform-density
        // dots — a clean halftone screen.
        let gray = CIImage(color: CIColor(red: 0.5, green: 0.5, blue: 0.5))
            .cropped(to: extent)
        let dotWidth = max(2.5, 3.0 + size * 10)
        return gray
            .applyingFilter("CIDotScreen", parameters: [
                kCIInputCenterKey: CIVector(x: extent.midX, y: extent.midY),
                kCIInputAngleKey: 0.4,
                kCIInputWidthKey: dotWidth,
                "inputSharpness": 0.5 + roughness * 0.4
            ])
            .cropped(to: extent)
            .applyingFilter("CIColorControls", parameters: [
                kCIInputSaturationKey: 0.0,
                kCIInputContrastKey: 1.3 + roughness * 0.5
            ])
    }

    /// **Silver Rich** — heavier crystals than Cubic, paired with a luma
    /// mask that pushes most of the grain into the shadows. Same fBm
    /// trick as Cubic but biased toward the coarse layer.
    private func silverRich(_ noise: CIImage, size: CGFloat, roughness: CGFloat) -> CIImage {
        let fineRadius = max(0.6, 0.8 + size * 2.0)
        let coarseRadius = max(3.0, 4.0 + size * 8.0)

        let fine = noise
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: fineRadius])
            .cropped(to: noise.extent)

        let coarse = noise
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: coarseRadius])
            .cropped(to: noise.extent)
            .applyingFilter("CIColorMatrix", parameters: [
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0.55)
            ])

        let combined = coarse
            .applyingFilter("CISourceOverCompositing", parameters: [
                kCIInputBackgroundImageKey: fine
            ])
            .cropped(to: noise.extent)

        return combined.applyingFilter("CIColorControls", parameters: [
            kCIInputContrastKey: 2.0 + roughness * 0.9,
            kCIInputSaturationKey: 0.0
        ])
    }

    /// **Soft** — pure low-frequency diffusion. A wide Gaussian rolls the
    /// per-pixel noise into atmospheric texture rather than per-pixel
    /// grain. Almost subliminal; reads as "atmosphere".
    private func soft(_ noise: CIImage, size: CGFloat, roughness: CGFloat) -> CIImage {
        let blurRadius = max(3.0, 4.0 + size * 14)
        return noise
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: blurRadius])
            .cropped(to: noise.extent)
            .applyingFilter("CIColorControls", parameters: [
                kCIInputContrastKey: 0.85 + roughness * 0.5,
                kCIInputSaturationKey: 0.0
            ])
    }

    /// **Plate** — wet-collodion: large irregular blob structures with
    /// finer texture inside. Built from THREE noise layers at descending
    /// scales (huge / medium / small) blended together so the overall
    /// pattern is coarse but not blocky and not regular.
    private func plate(_ noise: CIImage, size: CGFloat, roughness: CGFloat) -> CIImage {
        let macroRadius = max(8.0, 12.0 + size * 24.0)
        let midRadius = max(3.0, 4.0 + size * 8.0)
        let microRadius = max(0.5, 0.6 + size * 1.5)

        let macro = noise
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: macroRadius])
            .cropped(to: noise.extent)

        let mid = noise
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: midRadius])
            .cropped(to: noise.extent)
            .applyingFilter("CIColorMatrix", parameters: [
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0.45)
            ])

        let micro = noise
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: microRadius])
            .cropped(to: noise.extent)
            .applyingFilter("CIColorMatrix", parameters: [
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0.30)
            ])

        let midOnMacro = mid
            .applyingFilter("CISourceOverCompositing", parameters: [
                kCIInputBackgroundImageKey: macro
            ])
            .cropped(to: noise.extent)
        let combined = micro
            .applyingFilter("CISourceOverCompositing", parameters: [
                kCIInputBackgroundImageKey: midOnMacro
            ])
            .cropped(to: noise.extent)

        return combined.applyingFilter("CIColorControls", parameters: [
            kCIInputContrastKey: 1.5 + roughness * 0.7,
            kCIInputSaturationKey: 0.0
        ])
    }

    // MARK: - Luminance weighting

    private func makeLumaMask(image: CIImage, type: String) -> CIImage {
        let luma = image.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 0.2126, y: 0.7152, z: 0.0722, w: 0),
            "inputGVector": CIVector(x: 0.2126, y: 0.7152, z: 0.0722, w: 0),
            "inputBVector": CIVector(x: 0.2126, y: 0.7152, z: 0.0722, w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1)
        ])

        let peakLuma: Float
        let bandWidth: Float
        switch type {
        case GrainOp.typeSilverRich: peakLuma = 0.30; bandWidth = 0.45
        case GrainOp.typeNewsprint:  peakLuma = 0.50; bandWidth = 0.70
        case GrainOp.typeSoft:       peakLuma = 0.50; bandWidth = 0.65
        default:                     peakLuma = 0.50; bandWidth = 0.55
        }

        guard let gradient = Self.bellGradient(peak: peakLuma, width: bandWidth) else {
            return luma
        }
        return luma.applyingFilter("CIColorMap", parameters: [
            "inputGradientImage": gradient
        ])
    }

    private static func bellGradient(peak: Float, width: Float) -> CIImage? {
        var bytes = [Float](repeating: 0, count: 256 * 4)
        for i in 0..<256 {
            let x = Float(i) / 255
            let normDist = abs(x - peak) / max(0.05, width)
            let weight = max(0, 1 - normDist * normDist)
            bytes[i * 4 + 0] = weight
            bytes[i * 4 + 1] = weight
            bytes[i * 4 + 2] = weight
            bytes[i * 4 + 3] = 1
        }
        let data = bytes.withUnsafeBufferPointer { Data(buffer: $0) }
        return CIImage(
            bitmapData: data,
            bytesPerRow: 256 * MemoryLayout<Float>.size * 4,
            size: CGSize(width: 256, height: 1),
            format: .RGBAf,
            colorSpace: ColorSpaces.sRGB
        )
    }
}
