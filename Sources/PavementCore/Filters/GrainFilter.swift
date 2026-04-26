import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins

/// Capture-One-style film grain. Three architectural pillars:
///
/// 1. **Real procedural noise per type** — Simplex (Fine, Silver Rich,
///    Soft) and Voronoi (Cubic with isotropic cells, Tabular with
///    horizontally-stretched platelet cells). Harsh runs on per-pixel
///    uniform noise via CIRandomGenerator + a Hard Light blend.
///
/// 2. **Luminance bell-curve mask** — `4x(1-x)` weight where x is the
///    pixel's luminance. Peaks at 0.5 (full grain in midtones), tapers
///    smoothly to ZERO at pure black (0) and pure white (1) — clipped
///    pixels naturally get no grain. Reaches 36% at luma 0.1 / 0.9 so
///    grain stays visible across the whole image, just attenuated as
///    real silver does.
///
/// 3. **Per-type compositing** — most types add signed grain via
///    CIAdditionCompositing. Harsh uses CIHardLightBlendMode for the
///    gritty pushed-film feel.
///
/// Six types only in the picker (Fine / Cubic / Tabular / Silver Rich /
/// Soft / Harsh). The noise primitive is wired internally per type.
public struct GrainFilter {
    public init() {}

    public func apply(image: CIImage, op: GrainOp) -> CIImage {
        guard op.amount > 0 else { return image }
        let extent = image.extent
        guard extent.width.isFinite, extent.height.isFinite,
              extent.width > 0, extent.height > 0 else { return image }

        // 1. Generate per-type grain texture (gray, centered around 0.5).
        let grainBase = generateGrain(extent: extent, op: op)

        // 2. Luma bell-curve mask: 4x(1-x). Zero at clipped extremes,
        //    peak at midtones. Multiply grain by mask.
        let lumaMask = makeLumaMask(image: image)
        let weighted = grainBase.applyingFilter("CIMultiplyCompositing", parameters: [
            kCIInputBackgroundImageKey: lumaMask
        ])

        // 3. Sign + intensity scale, then composite.
        let intensity = CGFloat(op.amount) / 100.0 * 0.6
        let signed = weighted.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: intensity * 2, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: intensity * 2, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: intensity * 2, w: 0),
            "inputBiasVector": CIVector(x: -intensity, y: -intensity, z: -intensity, w: 0)
        ])

        if op.type == GrainOp.typeHarsh {
            // Hard Light: noise > 0.5 brightens (Screen), noise < 0.5
            // darkens (Multiply). Combined with the high-contrast
            // shaping below it gives the gritty pushed-film clumps.
            let neutralCentered = grainBase.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: intensity * 1.2 + 0.4, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: intensity * 1.2 + 0.4, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: intensity * 1.2 + 0.4, w: 0),
                "inputBiasVector": CIVector(x: 0.5 - (intensity * 0.6 + 0.2),
                                            y: 0.5 - (intensity * 0.6 + 0.2),
                                            z: 0.5 - (intensity * 0.6 + 0.2),
                                            w: 0)
            ])
            // Apply mask to the centered noise so masked regions stay
            // at neutral 0.5 (no Hard Light effect there).
            let mixed = blendTowardNeutral(noise: neutralCentered, mask: lumaMask)
            return mixed.applyingFilter("CIHardLightBlendMode", parameters: [
                kCIInputBackgroundImageKey: image
            ])
        }

        return signed.applyingFilter("CIAdditionCompositing", parameters: [
            kCIInputBackgroundImageKey: image
        ])
    }

    public static func isIdentity(_ op: GrainOp) -> Bool {
        op.amount == 0
    }

    // MARK: - Per-type noise

    private func generateGrain(extent: CGRect, op: GrainOp) -> CIImage {
        let size = CGFloat(op.size) / 100        // 0..1
        let roughness = CGFloat(op.roughness) / 100 // 0..1

        switch op.type {
        case GrainOp.typeFine:
            return fineNoise(extent: extent, size: size, roughness: roughness)
        case GrainOp.typeCubic:
            return voronoiCells(extent: extent, size: size, roughness: roughness, anisotropy: 1.0)
        case GrainOp.typeTabular:
            return voronoiCells(extent: extent, size: size, roughness: roughness, anisotropy: 2.6)
        case GrainOp.typeSilverRich:
            return silverRichNoise(extent: extent, size: size, roughness: roughness)
        case GrainOp.typeSoft:
            return softNoise(extent: extent, size: size, roughness: roughness)
        case GrainOp.typeHarsh:
            return harshNoise(extent: extent, size: size, roughness: roughness)
        default:
            return fineNoise(extent: extent, size: size, roughness: roughness)
        }
    }

    /// Fine: high-frequency Simplex with low persistence (single octave).
    private func fineNoise(extent: CGRect, size: CGFloat, roughness: CGFloat) -> CIImage {
        let scale = Float(0.4 + size * 0.8)  // small scale → high frequency
        guard let base = ProceduralNoise.image(
            algorithm: .simplex,
            scale: scale,
            octaves: 1,
            seed: 0xA1B2C3D4
        ) else { return neutralImage(extent: extent) }

        return upscaledShape(base, extent: extent,
                             contrast: 1.4 + Float(roughness) * 0.5)
    }

    /// Cubic / Tabular: Voronoi cellular noise. Cubic uses isotropic
    /// cells; Tabular stretches the distance metric horizontally so
    /// cells become flat platelets — sharp, structured, modern T-grain.
    private func voronoiCells(extent: CGRect, size: CGFloat, roughness: CGFloat, anisotropy: Float) -> CIImage {
        let scale = Float(0.6 + size * 1.4)
        guard let base = ProceduralNoise.image(
            algorithm: .voronoi,
            scale: scale,
            octaves: 1,
            anisotropy: anisotropy,
            seed: 0x5A5A_C0DE
        ) else { return neutralImage(extent: extent) }

        return upscaledShape(base, extent: extent,
                             contrast: 1.7 + Float(roughness) * 0.7,
                             extraBlur: 0.3)
    }

    /// Silver Rich: multi-octave Simplex (clumpy fractal) + extra
    /// contrast for that dense Ilford Delta 3200 silver-halide feel.
    private func silverRichNoise(extent: CGRect, size: CGFloat, roughness: CGFloat) -> CIImage {
        let scale = Float(0.5 + size * 1.0)
        let octaves = 2 + Int(roughness * 3)  // 2..5 octaves
        guard let base = ProceduralNoise.image(
            algorithm: .simplex,
            scale: scale,
            octaves: octaves,
            seed: 0x51_4E_45_52
        ) else { return neutralImage(extent: extent) }

        return upscaledShape(base, extent: extent,
                             contrast: 2.0 + Float(roughness) * 0.8)
    }

    /// Soft: per-pixel uniform noise (CIRandomGenerator) + heavy
    /// Gaussian blur. Diffuse, organic, atmospheric.
    private func softNoise(extent: CGRect, size: CGFloat, roughness: CGFloat) -> CIImage {
        let raw = (CIFilter.randomGenerator().outputImage ?? CIImage(color: .gray))
            .cropped(to: extent)
            .applyingFilter("CIColorMonochrome", parameters: [
                kCIInputColorKey: CIColor(red: 0.5, green: 0.5, blue: 0.5),
                kCIInputIntensityKey: 1.0
            ])
        let blur = max(2.0, 2.5 + size * 8)
        return raw
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: blur])
            .cropped(to: extent)
            .applyingFilter("CIColorControls", parameters: [
                kCIInputContrastKey: 0.9 + roughness * 0.4,
                kCIInputSaturationKey: 0.0
            ])
    }

    /// Harsh: per-pixel uniform noise with extreme contrast push.
    /// The output is composited via Hard Light for the gritty
    /// pushed-film texture.
    private func harshNoise(extent: CGRect, size: CGFloat, roughness: CGFloat) -> CIImage {
        let raw = (CIFilter.randomGenerator().outputImage ?? CIImage(color: .gray))
            .cropped(to: extent)
            .applyingFilter("CIColorMonochrome", parameters: [
                kCIInputColorKey: CIColor(red: 0.5, green: 0.5, blue: 0.5),
                kCIInputIntensityKey: 1.0
            ])
        let blur = max(0.4, 0.5 + size * 1.2)
        return raw
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: blur])
            .cropped(to: extent)
            .applyingFilter("CIColorControls", parameters: [
                kCIInputContrastKey: 2.5 + roughness * 1.5,
                kCIInputBrightnessKey: -0.05,
                kCIInputSaturationKey: 0.0
            ])
    }

    /// Common: scale a 1024² noise texture to image extent via Lanczos
    /// (preserves frequency content), apply per-image translation jitter
    /// so different photos get different patterns, then contrast-shape.
    private func upscaledShape(_ baseTexture: CIImage,
                               extent: CGRect,
                               contrast: Float,
                               extraBlur: Double = 0) -> CIImage {
        let scale = max(extent.width / baseTexture.extent.width,
                        extent.height / baseTexture.extent.height)
        let offsetX = CGFloat((Int(extent.width) &* 31 &+ Int(extent.height) &* 47) % 997)
        let offsetY = CGFloat((Int(extent.width) &* 53 &+ Int(extent.height) &* 71) % 991)

        var img = baseTexture
            .applyingFilter("CILanczosScaleTransform", parameters: [
                kCIInputScaleKey: scale,
                kCIInputAspectRatioKey: 1.0
            ])
            .transformed(by: CGAffineTransform(translationX: offsetX, y: offsetY))
            .cropped(to: extent)

        if extraBlur > 0 {
            img = img.applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: extraBlur])
                .cropped(to: extent)
        }

        return img.applyingFilter("CIColorControls", parameters: [
            kCIInputContrastKey: contrast,
            kCIInputSaturationKey: 0.0
        ])
    }

    private func neutralImage(extent: CGRect) -> CIImage {
        CIImage(color: CIColor(red: 0.5, green: 0.5, blue: 0.5)).cropped(to: extent)
    }

    // MARK: - Luminance mask (Capture One bell curve)

    /// Capture One's "secret sauce": grain peaks at 50% luminance and
    /// tapers smoothly to ZERO at pure 0 and pure 1. The polynomial
    /// `4x(1 - x)` is the simple bell that satisfies all three:
    /// peaks at 0.5 with value 1, hits exactly 0 at 0 and 1, smooth.
    /// Implemented as a 256-sample CIColorMap gradient applied to the
    /// image's Rec.709 luminance.
    private func makeLumaMask(image: CIImage) -> CIImage {
        let luma = image.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 0.2126, y: 0.7152, z: 0.0722, w: 0),
            "inputGVector": CIVector(x: 0.2126, y: 0.7152, z: 0.0722, w: 0),
            "inputBVector": CIVector(x: 0.2126, y: 0.7152, z: 0.0722, w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1)
        ])
        guard let gradient = Self.bellGradient() else { return luma }
        return luma.applyingFilter("CIColorMap", parameters: [
            "inputGradientImage": gradient
        ])
    }

    private static func bellGradient() -> CIImage? {
        var bytes = [Float](repeating: 0, count: 256 * 4)
        for i in 0..<256 {
            let x = Float(i) / 255
            let weight = 4 * x * (1 - x)   // peak 1.0 at x=0.5, zero at 0 and 1
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

    /// For Hard Light grain: take the centered noise and blend it
    /// toward neutral 0.5 by `(1 - mask)` so masked regions become
    /// neutral (no Hard Light effect at clipped extremes).
    /// Math: mixed = noise * mask + 0.5 * (1 - mask)
    /// Implemented as: (noise - 0.5) * mask + 0.5  via two CIColorMatrix
    /// steps and one Multiply.
    private func blendTowardNeutral(noise: CIImage, mask: CIImage) -> CIImage {
        let centered = noise.applyingFilter("CIColorMatrix", parameters: [
            "inputBiasVector": CIVector(x: -0.5, y: -0.5, z: -0.5, w: 0)
        ])
        let masked = centered.applyingFilter("CIMultiplyCompositing", parameters: [
            kCIInputBackgroundImageKey: mask
        ])
        return masked.applyingFilter("CIColorMatrix", parameters: [
            "inputBiasVector": CIVector(x: 0.5, y: 0.5, z: 0.5, w: 0)
        ])
    }
}
