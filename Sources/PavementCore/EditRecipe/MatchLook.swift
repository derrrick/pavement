import Foundation
import CoreImage

/// Derives a recipe of edits that tugs `current`'s color/tone toward
/// `reference`. Operates on Lab-space statistics (see ImageStatistics).
/// The aim is to capture the *aesthetic* — overall light/color tendency —
/// rather than literal pixel matching, so cross-content pairs (sunset
/// portrait vs daytime street) don't blow up.
public enum MatchLook {

    /// Per-parameter caps so cross-content pairs don't produce extreme
    /// recipes. Tuned via the research-suggested musical maxima.
    public static let maxExposureEV: Double = 1.5
    public static let maxContrastDelta: Int = 60
    public static let maxSaturationDelta: Int = 60
    public static let maxTempDeltaKelvin: Int = 1800
    public static let maxTintDelta: Int = 60
    public static let maxGradeSaturation: Int = 70

    public static func deriveOperations(
        from reference: ImageStatistics,
        current: ImageStatistics,
        intensity: Double = 1.0
    ) -> Operations {
        var ops = Operations()
        let strength = max(0, min(1, intensity))

        // 1. Exposure — match L means (soft mapping, capped).
        let lDelta = Double(reference.meanL - current.meanL) / 100.0  // -1..1
        ops.exposure.ev = clamp(lDelta * 2.5 * strength,
                                lower: -maxExposureEV,
                                upper: maxExposureEV)

        // 2. Contrast — match L percentile spread (P95 - P5) ratio in log space.
        let curSpread = max(1.0, Double(current.p95L - current.p5L))
        let refSpread = max(1.0, Double(reference.p95L - reference.p5L))
        let contrastDelta = log2(max(0.5, min(2.0, refSpread / curSpread))) * 100
        ops.tone.contrast = Int(clamp(contrastDelta * strength,
                                      lower: -Double(maxContrastDelta),
                                      upper: Double(maxContrastDelta)))
        let highlightDelta = Double(reference.p95L - current.p95L)
        let shadowDelta = Double(reference.p5L - current.p5L)
        ops.tone.highlights = Int(clamp(highlightDelta * 0.7 * strength,
                                        lower: -40,
                                        upper: 40))
        ops.tone.shadows = Int(clamp(shadowDelta * 0.9 * strength,
                                     lower: -45,
                                     upper: 45))
        if reference.p95L < current.p95L - 4 {
            ops.tone.highlightRecovery = Int(clamp((current.p95L - reference.p95L) * 1.5 * Float(strength),
                                                   lower: 0,
                                                   upper: 45))
        }
        ops.toneCurve.rgb = toneCurve(forContrast: ops.tone.contrast, shadowLift: ops.tone.shadows)

        // 3. Saturation — match chroma magnitude ratio.
        let curChroma = max(0.5, Double(current.chromaMagnitude))
        let refChroma = max(0.5, Double(reference.chromaMagnitude))
        let satDelta = (refChroma / curChroma - 1) * 50
        ops.color.saturation = Int(clamp(satDelta * strength,
                                         lower: -Double(maxSaturationDelta),
                                         upper: Double(maxSaturationDelta)))
        ops.color.vibrance = Int(clamp(satDelta * 0.45 * strength,
                                       lower: -35,
                                       upper: 35))

        // 4. White balance — a* drives tint, b* drives temperature.
        // Damp by content-similarity of L histograms (rough proxy via mean
        // difference; full Bhattacharyya overkill at this fidelity).
        let lContentDiff = abs(reference.meanL - current.meanL) / 50
        let wbDamp = max(0.4, 1.0 - Double(lContentDiff) * 0.6)
        let bDelta = Double(reference.meanB - current.meanB)
        let aDelta = Double(reference.meanA - current.meanA)
        let tempDelta = Int(clamp(bDelta * 150 * strength * wbDamp,
                                  lower: -Double(maxTempDeltaKelvin),
                                  upper: Double(maxTempDeltaKelvin)))
        let tintDelta = Int(clamp(aDelta * 3 * strength * wbDamp,
                                  lower: -Double(maxTintDelta),
                                  upper: Double(maxTintDelta)))
        if abs(tempDelta) > 50 || abs(tintDelta) > 2 {
            ops.whiteBalance.mode = WhiteBalanceOp.custom
            ops.whiteBalance.temp = max(2000, min(50000, 5500 + tempDelta))
            ops.whiteBalance.tint = max(-150, min(150, tintDelta))
        }

        // 5. Color grading — shadow/highlight chroma centroids → wheel tint.
        // These run at full strength because the shadow/highlight separation
        // is relative within each image, robust to scene mismatch.
        if let shadow = wheelFromCentroid(a: reference.shadowA, b: reference.shadowB,
                                          strength: strength) {
            ops.colorGrading.shadows = shadow
        }
        if let midtone = wheelFromCentroid(a: reference.meanA, b: reference.meanB,
                                           strength: strength * 0.55) {
            ops.colorGrading.midtones = midtone
        }
        if let highlight = wheelFromCentroid(a: reference.highlightA, b: reference.highlightB,
                                             strength: strength) {
            ops.colorGrading.highlights = highlight
        }
        ops.colorGrading.blending = 65
        ops.colorGrading.balance = Int(clamp(Double(reference.meanL - 50) * 0.6 * strength,
                                             lower: -35,
                                             upper: 35))

        ops.hsl.orange.s = Int(clamp(Double(ops.color.saturation) * -0.25,
                                     lower: -12,
                                     upper: 6))
        ops.hsl.orange.l = Int(clamp(Double(reference.meanL - current.meanL) * 0.12 * strength,
                                     lower: -8,
                                     upper: 8))
        ops.hsl.green.s = Int(clamp(Double(ops.color.saturation) * -0.18,
                                    lower: -18,
                                    upper: 8))

        var temp = EditRecipe()
        temp.operations = ops
        Clamping.clampInPlace(&temp)
        return temp.operations
    }

    private static func wheelFromCentroid(a: Float, b: Float, strength: Double) -> GradingWheel? {
        let magnitude = (a * a + b * b).squareRoot()
        guard magnitude > 2 else { return nil }
        let hueRad = atan2(Double(b), Double(a))
        var hueDeg = hueRad * 180 / .pi
        hueDeg = (hueDeg + 360).truncatingRemainder(dividingBy: 360)
        let sat = Int(clamp(Double(magnitude) * 1.5 * strength,
                            lower: 0,
                            upper: Double(maxGradeSaturation)))
        return GradingWheel(hue: Int(hueDeg.rounded()), sat: sat, lum: 0)
    }

    private static func toneCurve(forContrast contrast: Int, shadowLift: Int) -> [[Double]] {
        let c = clamp(Double(contrast) / 100.0, lower: -0.6, upper: 0.6)
        let lift = clamp(Double(shadowLift) / 100.0, lower: -0.25, upper: 0.25)
        let black = clamp(0.015 + max(0, lift) * 0.10, lower: 0.0, upper: 0.06)
        let shadowY = clamp(0.24 - c * 0.10 + lift * 0.20, lower: 0.08, upper: 0.38)
        let midY = clamp(0.50 + lift * 0.04, lower: 0.44, upper: 0.56)
        let highY = clamp(0.76 + c * 0.10, lower: 0.62, upper: 0.90)
        let white = clamp(0.99 - max(0, -lift) * 0.04, lower: 0.94, upper: 1.0)
        return [[0, black], [0.25, shadowY], [0.5, midY], [0.75, highY], [1, white]]
    }

    private static func clamp<T: Comparable>(_ value: T, lower: T, upper: T) -> T {
        min(max(value, lower), upper)
    }
}
