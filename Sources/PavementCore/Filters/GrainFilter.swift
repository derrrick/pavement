import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins

/// Procedural film grain. Each type pairs a real noise algorithm
/// (Voronoi / Perlin / Simplex / Value / Uniform / Gaussian) with a
/// shaping pipeline (blur, contrast, anisotropy) to recreate a
/// recognisable film/digital look.
///
/// The base noise is generated on CPU at a moderate resolution (768²)
/// and Lanczos-upsampled to the image extent — much better quality
/// than CIRandomGenerator + Pixellate, no visible tile pattern, and the
/// generated noise is cached so slider-drags on `amount` reuse the same
/// texture instead of regenerating per frame.
///
/// Real-film signature retained: luminance weighting via a bell-curve
/// gradient (peaks in midtones for most types, in shadows for Silver
/// Rich), so clipped extremes get ~no grain — matches Fujifilm's
/// in-camera grain effect.
public struct GrainFilter {
    public init() {}

    public func apply(image: CIImage, op: GrainOp) -> CIImage {
        guard op.amount > 0 else { return image }
        let extent = image.extent
        guard extent.width.isFinite, extent.height.isFinite,
              extent.width > 0, extent.height > 0 else { return image }

        // 1. Generate the per-type grain texture (gray, centered around 0.5)
        //    at the source extent.
        let grainBase = generateGrain(extent: extent, op: op)

        // 2. Weight by image luminance — bell curve peaking at midtones
        //    (or shadows for Silver Rich).
        let lumaMask = makeLumaMask(image: image, type: op.type)
        let weighted = grainBase.applyingFilter("CIMultiplyCompositing", parameters: [
            kCIInputBackgroundImageKey: lumaMask
        ])

        // 3. Sign + intensity scale, then add to image.
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

    // MARK: - Noise dispatch

    /// Pull a noise texture from ProceduralNoise (cached by params),
    /// upscale to the image extent, and run per-type shaping. Newsprint
    /// is special-cased to use CIDotScreen instead of a noise sample.
    private func generateGrain(extent: CGRect, op: GrainOp) -> CIImage {
        let size = CGFloat(op.size) / 100        // 0..1
        let roughness = CGFloat(op.roughness) / 100 // 0..1

        if op.type == GrainOp.typeNewsprint {
            return newsprintGrain(extent: extent, size: size, roughness: roughness)
        }

        let spec = typeSpec(for: op.type)
        guard let baseTexture = ProceduralNoise.image(
            algorithm: spec.algorithm,
            scale: spec.scale(Float(size)),
            octaves: spec.octaves(Float(roughness)),
            seed: 0xA1B2C3D4
        ) else {
            return CIImage(color: CIColor(red: 0.5, green: 0.5, blue: 0.5)).cropped(to: extent)
        }

        // Upscale the 768² noise texture to the image extent. Per-image
        // noise variation comes from the offset jitter we apply below.
        let scaleX = extent.width / baseTexture.extent.width
        let scaleY = extent.height / baseTexture.extent.height
        let scale = max(scaleX, scaleY)

        let offsetX = CGFloat((Int(extent.width) &* 31 &+ Int(extent.height) &* 47) % 997)
        let offsetY = CGFloat((Int(extent.width) &* 53 &+ Int(extent.height) &* 71) % 991)

        var upscaled = baseTexture
            .applyingFilter("CILanczosScaleTransform", parameters: [
                kCIInputScaleKey: scale,
                kCIInputAspectRatioKey: 1.0
            ])
            .transformed(by: CGAffineTransform(translationX: offsetX, y: offsetY))
            .cropped(to: extent)

        // Shape: motion blur for tabular, contrast push for harsh, etc.
        upscaled = spec.shape(upscaled, size, roughness)

        return upscaled
    }

    /// Newsprint: actual ordered halftone via CIDotScreen on flat gray.
    /// Genuinely regular dots — that's the look.
    private func newsprintGrain(extent: CGRect, size: CGFloat, roughness: CGFloat) -> CIImage {
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

    // MARK: - Per-type spec

    /// One spec per grain type — tells us which noise algorithm to feed,
    /// how to derive scale + octaves from the size/roughness sliders, and
    /// what shaping to apply afterwards.
    private struct TypeSpec {
        let algorithm: ProceduralNoise.Algorithm
        let scale: (Float) -> Float            // size 0..1 → noise scale
        let octaves: (Float) -> Int            // roughness 0..1 → octaves
        let shape: (CIImage, CGFloat, CGFloat) -> CIImage
    }

    private func typeSpec(for type: String) -> TypeSpec {
        switch type {

        case GrainOp.typeFine:
            // Fine modern digital grain: per-pixel uniform with light
            // contrast lift. Sharp, neutral, no clumping.
            return TypeSpec(
                algorithm: .uniform,
                scale: { _ in 1.0 },
                octaves: { _ in 1 },
                shape: { img, _, rough in
                    img.applyingFilter("CIColorControls", parameters: [
                        kCIInputContrastKey: 1.4 + rough * 0.5,
                        kCIInputSaturationKey: 0.0
                    ])
                }
            )

        case GrainOp.typeCubic:
            // T-MAX-style cubic: value noise gives crisp, sharply-defined
            // grain shapes; tighter contrast for crystal definition.
            return TypeSpec(
                algorithm: .value,
                scale: { 0.3 + $0 * 1.2 },
                octaves: { 1 + Int($0 * 3) },
                shape: { img, _, rough in
                    img.applyingFilter("CIColorControls", parameters: [
                        kCIInputContrastKey: 1.7 + rough * 0.6,
                        kCIInputSaturationKey: 0.0
                    ])
                }
            )

        case GrainOp.typeTabular:
            // T-grain: Perlin smoothness + horizontal motion blur for the
            // anisotropic platelet shape.
            return TypeSpec(
                algorithm: .perlin,
                scale: { 0.4 + $0 * 1.0 },
                octaves: { 1 + Int($0 * 2) },
                shape: { img, sz, rough in
                    let streak = max(2.0, 3.0 + sz * 9)
                    return img
                        .applyingFilter("CIMotionBlur", parameters: [
                            kCIInputRadiusKey: streak,
                            kCIInputAngleKey: 0.05
                        ])
                        .cropped(to: img.extent)
                        .applyingFilter("CIColorControls", parameters: [
                            kCIInputContrastKey: 1.4 + rough * 0.5,
                            kCIInputSaturationKey: 0.0
                        ])
                }
            )

        case GrainOp.typeSilverRich:
            // Silver halide: Voronoi cells map onto crystalline silver
            // grains. Slight Gaussian round-off so cell boundaries aren't
            // razor-sharp; high contrast.
            return TypeSpec(
                algorithm: .voronoi,
                scale: { 0.5 + $0 * 1.5 },
                octaves: { _ in 1 },
                shape: { img, sz, rough in
                    img
                        .applyingFilter("CIGaussianBlur", parameters: [
                            kCIInputRadiusKey: 0.5 + sz * 1.0
                        ])
                        .cropped(to: img.extent)
                        .applyingFilter("CIColorControls", parameters: [
                            kCIInputContrastKey: 2.0 + rough * 0.9,
                            kCIInputSaturationKey: 0.0
                        ])
                }
            )

        case GrainOp.typeSoft:
            // Diffuse atmospheric grain: smooth Perlin + heavy Gaussian.
            return TypeSpec(
                algorithm: .perlin,
                scale: { 0.6 + $0 * 1.5 },
                octaves: { _ in 1 },
                shape: { img, sz, rough in
                    let blur = max(3.0, 4.0 + sz * 14)
                    return img
                        .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: blur])
                        .cropped(to: img.extent)
                        .applyingFilter("CIColorControls", parameters: [
                            kCIInputContrastKey: 0.85 + rough * 0.5,
                            kCIInputSaturationKey: 0.0
                        ])
                }
            )

        case GrainOp.typeCameraRaw:
            // Camera Raw–style: classic fBm via multi-octave Perlin where
            // roughness drives the octave count (fractal complexity).
            return TypeSpec(
                algorithm: .perlin,
                scale: { 0.4 + $0 * 1.4 },
                octaves: { 2 + Int($0 * 4) },     // 2..6 octaves
                shape: { img, _, rough in
                    img.applyingFilter("CIColorControls", parameters: [
                        kCIInputContrastKey: 1.5 + rough * 0.6,
                        kCIInputSaturationKey: 0.0
                    ])
                }
            )

        case GrainOp.typeHarsh:
            // Pushed film: per-pixel uniform with extreme contrast → the
            // grain is gritty and chunky-looking even at low amount.
            return TypeSpec(
                algorithm: .uniform,
                scale: { _ in 1.0 },
                octaves: { _ in 1 },
                shape: { img, _, rough in
                    img.applyingFilter("CIColorControls", parameters: [
                        kCIInputContrastKey: 2.5 + rough * 1.5,
                        kCIInputBrightnessKey: -0.05,
                        kCIInputSaturationKey: 0.0
                    ])
                }
            )

        case GrainOp.typePlate:
            // Wet-collodion: huge Voronoi cells with a soft Gaussian to
            // round the blob edges into organic patches.
            return TypeSpec(
                algorithm: .voronoi,
                scale: { 1.5 + $0 * 2.0 },
                octaves: { _ in 1 },
                shape: { img, sz, rough in
                    let blur = max(3.0, 4.0 + sz * 6)
                    return img
                        .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: blur])
                        .cropped(to: img.extent)
                        .applyingFilter("CIColorControls", parameters: [
                            kCIInputContrastKey: 1.4 + rough * 0.6,
                            kCIInputSaturationKey: 0.0
                        ])
                }
            )

        // Pure-algorithm types: surface the raw noise with minimal shaping
        // so power users can pick a primitive directly.

        case GrainOp.typeUniform:
            return TypeSpec(
                algorithm: .uniform,
                scale: { _ in 1.0 },
                octaves: { _ in 1 },
                shape: { img, _, rough in
                    img.applyingFilter("CIColorControls", parameters: [
                        kCIInputContrastKey: 1.0 + rough * 0.6,
                        kCIInputSaturationKey: 0.0
                    ])
                }
            )

        case GrainOp.typeGaussian:
            return TypeSpec(
                algorithm: .gaussian,
                scale: { _ in 1.0 },
                octaves: { _ in 1 },
                shape: { img, _, rough in
                    img.applyingFilter("CIColorControls", parameters: [
                        kCIInputContrastKey: 1.2 + rough * 0.5,
                        kCIInputSaturationKey: 0.0
                    ])
                }
            )

        case GrainOp.typePerlin:
            return TypeSpec(
                algorithm: .perlin,
                scale: { 0.4 + $0 * 1.5 },
                octaves: { 1 + Int($0 * 5) },
                shape: { img, _, rough in
                    img.applyingFilter("CIColorControls", parameters: [
                        kCIInputContrastKey: 1.3 + rough * 0.5,
                        kCIInputSaturationKey: 0.0
                    ])
                }
            )

        case GrainOp.typeSimplex:
            return TypeSpec(
                algorithm: .simplex,
                scale: { 0.4 + $0 * 1.5 },
                octaves: { 1 + Int($0 * 5) },
                shape: { img, _, rough in
                    img.applyingFilter("CIColorControls", parameters: [
                        kCIInputContrastKey: 1.3 + rough * 0.5,
                        kCIInputSaturationKey: 0.0
                    ])
                }
            )

        case GrainOp.typeValue:
            return TypeSpec(
                algorithm: .value,
                scale: { 0.5 + $0 * 1.5 },
                octaves: { 1 + Int($0 * 4) },
                shape: { img, _, rough in
                    img.applyingFilter("CIColorControls", parameters: [
                        kCIInputContrastKey: 1.5 + rough * 0.5,
                        kCIInputSaturationKey: 0.0
                    ])
                }
            )

        case GrainOp.typeVoronoi:
            return TypeSpec(
                algorithm: .voronoi,
                scale: { 0.5 + $0 * 2.0 },
                octaves: { _ in 1 },
                shape: { img, _, rough in
                    img.applyingFilter("CIColorControls", parameters: [
                        kCIInputContrastKey: 1.6 + rough * 0.6,
                        kCIInputSaturationKey: 0.0
                    ])
                }
            )

        default:
            // Fallback: Fine
            return typeSpec(for: GrainOp.typeFine)
        }
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
        case GrainOp.typeHarsh:      peakLuma = 0.50; bandWidth = 0.60
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
