import Foundation
import CoreImage

/// Procedural film grain via a Metal compute kernel.
///
/// All math lives in `GrainKernel.metal`:
///   1. Per-pixel PCG3D hash of `(x, y, seed)` → deterministic, no
///      tiling, doesn't shimmer when other sliders change.
///   2. Six type-specific noise primitives (Fine, Cubic, Tabular,
///      Silver Rich, Soft, Harsh) — different mathematical
///      distributions, not just blur radius.
///   3. Luma bell mask `1 - |2L-1|^falloff` (peaks at 0.5, zero at
///      clipped 0/1 — matches how silver halide actually behaves).
///   4. Composite: `output = input + signed_noise * amount * mask`.
///
/// This module only translates UI sliders into kernel params. The
/// kernel itself runs at output resolution with zero persistent
/// allocations — a 100MP RAW costs the same memory as a 1MP preview.
public struct GrainFilter {
    public init() {}

    public func apply(image: CIImage, op: GrainOp) -> CIImage {
        guard op.amount > 0 else { return image }

        let amount = Float(op.amount) / 100         // 0..1
        let size = Float(op.size) / 100             // 0..1
        let roughness = Float(op.roughness) / 100   // 0..1

        let typeIndex: Int32 = Self.typeIndex(for: op.type)
        let granularity = Self.granularity(for: op.type, size: size)
        let falloff = Self.falloff(for: op.type)
        let amountScaled = Self.amountScale(for: op.type) * amount
        let roughnessScaled = Self.roughnessScale(for: op.type, roughness: roughness)
        let seed = Self.seed(for: image.extent, type: typeIndex)

        let params = GrainProcessor.Params(
            amount: amountScaled,
            granularity: granularity,
            roughness: roughnessScaled,
            falloff: falloff,
            type: typeIndex,
            seed: seed,
            // origin + extentScale are stamped per-dispatch in
            // GrainProcessor.process() from output.region and the
            // destination texture dimensions. The values here are unused.
            originX: 0,
            originY: 0,
            extentScaleX: 1,
            extentScaleY: 1
        )
        return GrainProcessor.apply(image: image, params: params)
    }

    public static func isIdentity(_ op: GrainOp) -> Bool {
        op.amount == 0
    }

    // MARK: - Slider → kernel parameter mapping

    /// Granularity = pixel-units per noise cell. Larger = bigger grain.
    /// Each type has its own range so the slider feels right per-type:
    /// Fine wants tight 0.7..3px cells; Soft wants chunky 4..20px.
    private static func granularity(for type: String, size: Float) -> Float {
        switch type {
        case GrainOp.typeFine:       return 0.7  + size * 2.3
        case GrainOp.typeCubic:      return 1.0  + size * 4.0
        case GrainOp.typeTabular:    return 1.2  + size * 5.0
        case GrainOp.typeSilverRich: return 1.0  + size * 6.0
        // Soft used to start at granularity 4 — already too chunky. The
        // user wants size=0..100 to span sub-pixel-to-medium, not "big to
        // huge." 0.8 → effectively per-pixel; 5.5 → comfortable max for a
        // diffuse atmospheric grain. Anything above 5.5 stops reading as
        // "soft" and starts reading as "smudgy."
        case GrainOp.typeSoft:       return 0.8  + size * 4.7
        case GrainOp.typeHarsh:      return 1.0  + size * 4.0
        default:                     return 1.0  + size * 3.0
        }
    }

    /// Roughness controls noise amplitude AND (in the shader for Harsh)
    /// the contrast curve. Mapping per-type so the slider feels useful.
    private static func roughnessScale(for type: String, roughness: Float) -> Float {
        switch type {
        case GrainOp.typeFine:       return 0.30 + roughness * 0.50  // gentle
        case GrainOp.typeCubic:      return 0.45 + roughness * 0.65
        case GrainOp.typeTabular:    return 0.40 + roughness * 0.60
        case GrainOp.typeSilverRich: return 0.50 + roughness * 0.70
        case GrainOp.typeSoft:       return 0.25 + roughness * 0.45  // diffuse
        case GrainOp.typeHarsh:      return 0.65 + roughness * 0.85  // gritty
        default:                     return 0.40 + roughness * 0.60
        }
    }

    /// Amount scale — global multiplier on top of UI amount. Some types
    /// (Soft, Fine) want lower base amplitude so 100% doesn't blow out.
    private static func amountScale(for type: String) -> Float {
        switch type {
        case GrainOp.typeFine:       return 0.55
        case GrainOp.typeCubic:      return 0.60
        case GrainOp.typeTabular:    return 0.55
        case GrainOp.typeSilverRich: return 0.65
        case GrainOp.typeSoft:       return 0.45
        case GrainOp.typeHarsh:      return 0.75
        default:                     return 0.60
        }
    }

    /// Bell falloff exponent. 2.0 = standard 4L(1-L) bell. Higher widens.
    private static func falloff(for type: String) -> Float {
        switch type {
        case GrainOp.typeSoft:       return 1.4   // wider — into shadows / highlights
        case GrainOp.typeHarsh:      return 2.5   // tighter — punches midtones
        default:                     return 2.0
        }
    }

    /// Maps the GrainOp type string to the kernel's switch index.
    private static func typeIndex(for type: String) -> Int32 {
        switch type {
        case GrainOp.typeFine:       return 0
        case GrainOp.typeCubic:      return 1
        case GrainOp.typeTabular:    return 2
        case GrainOp.typeSilverRich: return 3
        case GrainOp.typeSoft:       return 4
        case GrainOp.typeHarsh:      return 5
        default:                     return 0
        }
    }

    /// Stable per-image seed hashed from extent + type. Same image +
    /// type → same seed → same noise pattern. Different image OR
    /// different type → different seed → independent pattern. Slider
    /// drags don't change the seed, so the noise doesn't crawl.
    private static func seed(for extent: CGRect, type: Int32) -> UInt32 {
        let w = UInt32(truncatingIfNeeded: Int(extent.width.rounded()))
        let h = UInt32(truncatingIfNeeded: Int(extent.height.rounded()))
        var hash: UInt32 = w &* 0x9E37_79B9
        hash = hash &+ (h &* 0x85EB_CA6B)
        hash ^= UInt32(truncatingIfNeeded: type) &* 0xC2B2_AE35
        hash ^= hash >> 13
        hash &*= 0x85EB_CA6B
        hash ^= hash >> 16
        return hash == 0 ? 0xDEAD_BEEF : hash
    }
}
