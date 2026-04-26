import Foundation

/// Single-shot auto-adjust: compute reasonable starting values for
/// exposure / contrast / white balance from the image's Lab statistics.
/// Conservative — we don't want "Auto" to lock the user into a recipe
/// they'd then have to dial back. Caps at ±2 EV / ±50 contrast / ±1500K.
public enum AutoAdjust {
    public static func operations(from stats: ImageStatistics) -> Operations {
        var ops = Operations()

        // Target mean L* of 50 (perceptual middle gray). Soft mapping.
        let lDelta = Double(50 - stats.meanL) / 100  // -0.5..0.5 typical
        ops.exposure.ev = max(-2.0, min(2.0, lDelta * 3.5))

        // Stretch percentile spread toward [5, 95].
        let curSpread = max(1.0, Double(stats.p95L - stats.p5L))
        let targetSpread = 90.0
        let contrastShift = (targetSpread / curSpread - 1) * 50
        ops.tone.contrast = Int(max(-50, min(50, contrastShift)))
        if stats.p95L > 92 {
            ops.tone.highlightRecovery = min(45, Int((stats.p95L - 92) * 5))
            ops.tone.highlights = -min(35, Int((stats.p95L - 92) * 4))
        }

        // Gray-world WB: a*/b* mean → temperature/tint shift, opposite sign.
        if abs(stats.meanA) > 2 || abs(stats.meanB) > 2 {
            ops.whiteBalance.mode = WhiteBalanceOp.custom
            // Positive b* = warm cast in image → push target temp cooler to neutralize
            let tempDelta = Int(Double(-stats.meanB) * 80)
            let tintDelta = Int(Double(-stats.meanA) * 2)
            ops.whiteBalance.temp = max(2000, min(50000, 5500 + max(-1500, min(1500, tempDelta))))
            ops.whiteBalance.tint = max(-150, min(150, max(-60, min(60, tintDelta))))
        }

        return ops
    }
}
