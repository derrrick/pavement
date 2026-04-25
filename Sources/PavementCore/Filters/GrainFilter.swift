import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins

/// Procedural film grain. Six visually distinct types — each starts from
/// the same random noise but transforms it into a noticeably different
/// spatial pattern, then weights by image luminance the way real film
/// does (most visible in midtones, fading to nothing at clipped extremes).
///
/// Real film + Fujifilm-style grain is the reference: monochrome luma
/// noise, never colored, intensified in midtones. Highlights and crushed
/// shadows have less grain because there's less silver structure there.
public struct GrainFilter {
    public init() {}

    public func apply(image: CIImage, op: GrainOp) -> CIImage {
        guard op.amount > 0 else { return image }
        let extent = image.extent
        guard extent.width.isFinite, extent.height.isFinite,
              extent.width > 0, extent.height > 0 else { return image }

        // 1. Generate the per-type grain texture (gray, centered around 0.5).
        let grainBase = generateGrain(extent: extent, op: op)

        // 2. Weight by image luminance — bell curve peaking at midtones
        // (or shadows for Silver Rich). Pixels at clipped extremes
        // receive ~no grain, midtones receive full strength.
        let lumaMask = makeLumaMask(image: image, type: op.type)
        let weighted = grainBase.applyingFilter("CIMultiplyCompositing", parameters: [
            kCIInputBackgroundImageKey: lumaMask
        ])

        // 3. Sign + intensify: map grain from [0..1]·mask to [-i..+i]·mask
        // so it brightens AND darkens around each pixel.
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

    // MARK: - Per-type grain generators

    private func generateGrain(extent: CGRect, op: GrainOp) -> CIImage {
        let raw = CIFilter.randomGenerator().outputImage ?? CIImage(color: .gray)
        let monochromeNoise = raw
            .cropped(to: extent)
            .applyingFilter("CIColorMonochrome", parameters: [
                kCIInputColorKey: CIColor(red: 0.5, green: 0.5, blue: 0.5),
                kCIInputIntensityKey: 1.0
            ])

        let size = CGFloat(op.size) / 100        // 0..1
        let roughness = CGFloat(op.roughness) / 100   // 0..1

        switch op.type {
        case GrainOp.typeCubic:      return cubic(monochromeNoise, size: size, roughness: roughness)
        case GrainOp.typeTabular:    return tabular(monochromeNoise, size: size, roughness: roughness)
        case GrainOp.typeNewsprint:  return newsprint(monochromeNoise, size: size, roughness: roughness)
        case GrainOp.typeSilverRich: return silverRich(monochromeNoise, size: size, roughness: roughness)
        case GrainOp.typeSoft:       return soft(monochromeNoise, size: size, roughness: roughness)
        case GrainOp.typePlate:      return plate(monochromeNoise, size: size, roughness: roughness)
        default:                     return cubic(monochromeNoise, size: size, roughness: roughness)
        }
    }

    /// **Cubic** — classic sharp silver-halide grain. Pixel-level random
    /// structure with crisp edges. Size enlarges via small block grouping;
    /// roughness pushes contrast.
    private func cubic(_ noise: CIImage, size: CGFloat, roughness: CGFloat) -> CIImage {
        let blockSize = max(1.0, 1.0 + size * 2.5)
        return noise
            .applyingFilter("CIPixellate", parameters: [
                kCIInputCenterKey: CIVector(x: 0, y: 0),
                kCIInputScaleKey: blockSize
            ])
            .cropped(to: noise.extent)
            .applyingFilter("CIColorControls", parameters: [
                kCIInputContrastKey: 1.6 + roughness * 0.6,
                kCIInputSaturationKey: 0.0
            ])
    }

    /// **Tabular** — modern T-grain. Heavy directional motion blur creates
    /// elongated, anisotropic streaks; lower contrast than cubic so the
    /// grain reads as flatter and more spread out.
    private func tabular(_ noise: CIImage, size: CGFloat, roughness: CGFloat) -> CIImage {
        let streakLength = max(2.0, 2.5 + size * 9)
        return noise
            .applyingFilter("CIMotionBlur", parameters: [
                kCIInputRadiusKey: streakLength,
                kCIInputAngleKey: 0.05  // near-horizontal
            ])
            .cropped(to: noise.extent)
            .applyingFilter("CIColorControls", parameters: [
                kCIInputContrastKey: 1.3 + roughness * 0.5,
                kCIInputSaturationKey: 0.0
            ])
    }

    /// **Newsprint** — pixelated + extreme contrast collapses the noise
    /// to nearly-binary blocks. Reads as ordered halftone-ish dots, not
    /// continuous grain.
    private func newsprint(_ noise: CIImage, size: CGFloat, roughness: CGFloat) -> CIImage {
        let blockSize = max(3.0, 3.5 + size * 9)
        let pixelated = noise
            .applyingFilter("CIPixellate", parameters: [
                kCIInputCenterKey: CIVector(x: 0, y: 0),
                kCIInputScaleKey: blockSize
            ])
            .cropped(to: noise.extent)
        // Push contrast hard so values cluster near 0 and 1.
        return pixelated.applyingFilter("CIColorControls", parameters: [
            kCIInputContrastKey: 5.0 + roughness * 2.5,
            kCIInputBrightnessKey: -0.08,
            kCIInputSaturationKey: 0.0
        ])
    }

    /// **Silver Rich** — Ilford Delta 3200 vibe: medium-large, harsh,
    /// shadow-weighted grain. The shadow weighting comes from the luma
    /// mask (peakLuma 0.30); here we make the grain itself larger and
    /// crunchier than cubic.
    private func silverRich(_ noise: CIImage, size: CGFloat, roughness: CGFloat) -> CIImage {
        let blockSize = max(1.5, 2.0 + size * 4.5)
        let chunky = noise
            .applyingFilter("CIPixellate", parameters: [
                kCIInputCenterKey: CIVector(x: 0, y: 0),
                kCIInputScaleKey: blockSize
            ])
            .cropped(to: noise.extent)
        // Slight blur to soften block edges (silver crystals aren't squares)
        let softened = chunky
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 0.6])
            .cropped(to: noise.extent)
        return softened.applyingFilter("CIColorControls", parameters: [
            kCIInputContrastKey: 2.1 + roughness * 0.9,
            kCIInputSaturationKey: 0.0
        ])
    }

    /// **Soft** — heavily diffused organic grain. Wide Gaussian blur
    /// produces low-frequency, gentle texture rather than per-pixel
    /// noise. Reads as "atmospheric" — almost subliminal grain.
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

    /// **Plate** — wet-collodion: huge blotchy structures with finer
    /// detail riding inside. Big pixellation gives the macro pattern;
    /// a smaller noise overlay adds within-blob texture.
    private func plate(_ noise: CIImage, size: CGFloat, roughness: CGFloat) -> CIImage {
        let blobScale = max(10.0, 14.0 + size * 36)
        let blobs = noise
            .applyingFilter("CIPixellate", parameters: [
                kCIInputCenterKey: CIVector(x: 0, y: 0),
                kCIInputScaleKey: blobScale
            ])
            .cropped(to: noise.extent)
        // Smooth pixellated edges into organic blobs
        let smoothBlobs = blobs
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: blobScale * 0.35])
            .cropped(to: noise.extent)

        // Inner detail: smaller-scale noise to add texture inside each blob
        let detail = noise
            .applyingFilter("CIPixellate", parameters: [
                kCIInputCenterKey: CIVector(x: 0, y: 0),
                kCIInputScaleKey: max(2.0, blobScale * 0.12)
            ])
            .cropped(to: noise.extent)
            .applyingFilter("CIColorMatrix", parameters: [
                // 35% alpha so it tints the blobs without overwhelming
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0.35)
            ])

        let combined = detail.composited(over: smoothBlobs).cropped(to: noise.extent)
        return combined.applyingFilter("CIColorControls", parameters: [
            kCIInputContrastKey: 1.4 + roughness * 0.6,
            kCIInputSaturationKey: 0.0
        ])
    }

    // MARK: - Luminance weighting

    /// Builds a per-pixel mask from the image's luminance. The mask peaks
    /// where grain should be most visible (midtones for most types,
    /// shadows for Silver Rich) and rolls off to zero at clipped
    /// extremes — the signature of real film grain.
    private func makeLumaMask(image: CIImage, type: String) -> CIImage {
        // Compute Rec.709 luma into all channels: R=G=B=Y, A=1.
        let luma = image.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 0.2126, y: 0.7152, z: 0.0722, w: 0),
            "inputGVector": CIVector(x: 0.2126, y: 0.7152, z: 0.0722, w: 0),
            "inputBVector": CIVector(x: 0.2126, y: 0.7152, z: 0.0722, w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1)
        ])

        // Per-type peak + width tuning
        let peakLuma: Float
        let bandWidth: Float
        switch type {
        case GrainOp.typeSilverRich:
            peakLuma = 0.30
            bandWidth = 0.45
        case GrainOp.typeNewsprint:
            peakLuma = 0.50
            bandWidth = 0.70
        case GrainOp.typeSoft:
            peakLuma = 0.50
            bandWidth = 0.65
        default:
            peakLuma = 0.50
            bandWidth = 0.55
        }

        guard let gradient = Self.bellGradient(peak: peakLuma, width: bandWidth) else {
            return luma
        }
        return luma.applyingFilter("CIColorMap", parameters: [
            "inputGradientImage": gradient
        ])
    }

    /// 256-px wide horizontal gradient encoding a parabolic bell at `peak`
    /// with a half-width of `width`. Cached per call (cheap to rebuild).
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
