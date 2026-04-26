import Foundation

extension Operations {
    /// Returns a copy of the operation stack interpolated toward neutral
    /// values. This gives presets/styles a real amount control without
    /// muddying the image by blending rendered pixels.
    public func scaled(by amount: Double) -> Operations {
        let t = Clamping.clamp(amount, to: 0.0...1.0)
        let base = Operations()

        return Operations(
            crop: crop,
            lensCorrection: lensCorrection,
            whiteBalance: whiteBalance,
            exposure: ExposureOp(ev: exposure.ev * t),
            tone: tone.scaled(by: t),
            color: color.scaled(by: t),
            toneCurve: toneCurve.scaled(by: t),
            hsl: hsl.scaled(by: t),
            colorGrading: colorGrading.scaled(by: t),
            bw: bw.scaled(by: t),
            detail: detail.scaled(from: base.detail, by: t),
            grain: grain.scaled(from: base.grain, by: t),
            vignette: vignette.scaled(from: base.vignette, by: t)
        )
    }
}

private extension ToneOp {
    func scaled(by t: Double) -> ToneOp {
        ToneOp(
            contrast: scale(contrast, by: t),
            highlights: scale(highlights, by: t),
            shadows: scale(shadows, by: t),
            whites: scale(whites, by: t),
            blacks: scale(blacks, by: t),
            highlightRecovery: scale(highlightRecovery, by: t)
        )
    }
}

private extension ColorOp {
    func scaled(by t: Double) -> ColorOp {
        ColorOp(
            hue: scale(hue, by: t),
            saturation: scale(saturation, by: t),
            vibrance: scale(vibrance, by: t),
            luminance: scale(luminance, by: t)
        )
    }
}

private extension ToneCurveOp {
    func scaled(by t: Double) -> ToneCurveOp {
        ToneCurveOp(
            rgb: scaleCurve(rgb, by: t),
            r: scaleCurve(r, by: t),
            g: scaleCurve(g, by: t),
            b: scaleCurve(b, by: t)
        )
    }
}

private extension HSLOp {
    func scaled(by t: Double) -> HSLOp {
        HSLOp(
            red: red.scaled(by: t),
            orange: orange.scaled(by: t),
            yellow: yellow.scaled(by: t),
            green: green.scaled(by: t),
            aqua: aqua.scaled(by: t),
            blue: blue.scaled(by: t),
            purple: purple.scaled(by: t),
            magenta: magenta.scaled(by: t)
        )
    }
}

private extension HSLBand {
    func scaled(by t: Double) -> HSLBand {
        HSLBand(h: scale(h, by: t), s: scale(s, by: t), l: scale(l, by: t))
    }
}

private extension ColorGradingOp {
    func scaled(by t: Double) -> ColorGradingOp {
        ColorGradingOp(
            shadows: shadows.scaled(by: t),
            midtones: midtones.scaled(by: t),
            highlights: highlights.scaled(by: t),
            global: global.scaled(by: t),
            blending: scale(blending, from: 50, by: t),
            balance: scale(balance, by: t)
        )
    }
}

private extension GradingWheel {
    func scaled(by t: Double) -> GradingWheel {
        GradingWheel(
            hue: sat == 0 && lum == 0 ? 0 : hue,
            sat: scale(sat, by: t),
            lum: scale(lum, by: t)
        )
    }
}

private extension BWOp {
    func scaled(by t: Double) -> BWOp {
        BWOp(enabled: enabled && t > 0, mix: mix.scaled(by: t))
    }
}

private extension BWMix {
    func scaled(by t: Double) -> BWMix {
        BWMix(
            red: scale(red, by: t),
            orange: scale(orange, by: t),
            yellow: scale(yellow, by: t),
            green: scale(green, by: t),
            aqua: scale(aqua, by: t),
            blue: scale(blue, by: t),
            purple: scale(purple, by: t),
            magenta: scale(magenta, by: t)
        )
    }
}

private extension DetailOp {
    func scaled(from base: DetailOp, by t: Double) -> DetailOp {
        DetailOp(
            sharpAmount: scale(sharpAmount, from: base.sharpAmount, by: t),
            sharpRadius: scale(sharpRadius, from: base.sharpRadius, by: t),
            sharpMasking: scale(sharpMasking, from: base.sharpMasking, by: t),
            noiseLuma: scale(noiseLuma, from: base.noiseLuma, by: t),
            noiseColor: scale(noiseColor, from: base.noiseColor, by: t)
        )
    }
}

private extension GrainOp {
    func scaled(from base: GrainOp, by t: Double) -> GrainOp {
        GrainOp(
            amount: scale(amount, from: base.amount, by: t),
            size: scale(size, from: base.size, by: t),
            roughness: scale(roughness, from: base.roughness, by: t),
            type: t > 0 ? type : base.type
        )
    }
}

private extension VignetteOp {
    func scaled(from base: VignetteOp, by t: Double) -> VignetteOp {
        VignetteOp(
            amount: scale(amount, from: base.amount, by: t),
            midpoint: scale(midpoint, from: base.midpoint, by: t),
            feather: scale(feather, from: base.feather, by: t),
            roundness: scale(roundness, from: base.roundness, by: t)
        )
    }
}

private func scale(_ value: Int, by amount: Double) -> Int {
    Int((Double(value) * amount).rounded())
}

private func scale(_ value: Int, from base: Int, by amount: Double) -> Int {
    Int((Double(base) + (Double(value - base) * amount)).rounded())
}

private func scale(_ value: Double, from base: Double, by amount: Double) -> Double {
    base + ((value - base) * amount)
}

private func scaleCurve(_ points: [[Double]], by amount: Double) -> [[Double]] {
    guard !points.isEmpty else { return ToneCurveOp.identity }
    return points.map { point in
        guard point.count >= 2 else { return point }
        let x = point[0]
        let y = x + ((point[1] - x) * amount)
        return [x, y]
    }
}
