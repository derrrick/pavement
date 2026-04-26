import Foundation

public struct Operations: Equatable {
    public var crop: CropOp
    public var lensCorrection: LensCorrectionOp
    public var whiteBalance: WhiteBalanceOp
    public var exposure: ExposureOp
    public var tone: ToneOp
    public var color: ColorOp
    public var toneCurve: ToneCurveOp
    public var hsl: HSLOp
    public var colorGrading: ColorGradingOp
    public var bw: BWOp
    public var detail: DetailOp
    public var grain: GrainOp
    public var vignette: VignetteOp

    public init(
        crop: CropOp = .init(),
        lensCorrection: LensCorrectionOp = .init(),
        whiteBalance: WhiteBalanceOp = .init(),
        exposure: ExposureOp = .init(),
        tone: ToneOp = .init(),
        color: ColorOp = .init(),
        toneCurve: ToneCurveOp = .init(),
        hsl: HSLOp = .init(),
        colorGrading: ColorGradingOp = .init(),
        bw: BWOp = .init(),
        detail: DetailOp = .init(),
        grain: GrainOp = .init(),
        vignette: VignetteOp = .init()
    ) {
        self.crop = crop
        self.lensCorrection = lensCorrection
        self.whiteBalance = whiteBalance
        self.exposure = exposure
        self.tone = tone
        self.color = color
        self.toneCurve = toneCurve
        self.hsl = hsl
        self.colorGrading = colorGrading
        self.bw = bw
        self.detail = detail
        self.grain = grain
        self.vignette = vignette
    }
}

extension Operations: Codable {
    private enum CodingKeys: String, CodingKey {
        case crop, lensCorrection, whiteBalance, exposure, tone, color
        case toneCurve, hsl, colorGrading, bw, detail, grain, vignette
    }

    /// All fields decode-with-default so older sidecars (or sidecars from
    /// other tools that omit operations entirely) still load. Newer fields
    /// like `color` simply get their default value when absent.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.crop           = (try? c.decodeIfPresent(CropOp.self,           forKey: .crop))           ?? CropOp()
        self.lensCorrection = (try? c.decodeIfPresent(LensCorrectionOp.self, forKey: .lensCorrection)) ?? LensCorrectionOp()
        self.whiteBalance   = (try? c.decodeIfPresent(WhiteBalanceOp.self,   forKey: .whiteBalance))   ?? WhiteBalanceOp()
        self.exposure       = (try? c.decodeIfPresent(ExposureOp.self,       forKey: .exposure))       ?? ExposureOp()
        self.tone           = (try? c.decodeIfPresent(ToneOp.self,           forKey: .tone))           ?? ToneOp()
        self.color          = (try? c.decodeIfPresent(ColorOp.self,          forKey: .color))          ?? ColorOp()
        self.toneCurve      = (try? c.decodeIfPresent(ToneCurveOp.self,      forKey: .toneCurve))      ?? ToneCurveOp()
        self.hsl            = (try? c.decodeIfPresent(HSLOp.self,            forKey: .hsl))            ?? HSLOp()
        self.colorGrading   = (try? c.decodeIfPresent(ColorGradingOp.self,   forKey: .colorGrading))   ?? ColorGradingOp()
        self.bw             = (try? c.decodeIfPresent(BWOp.self,             forKey: .bw))             ?? BWOp()
        self.detail         = (try? c.decodeIfPresent(DetailOp.self,         forKey: .detail))         ?? DetailOp()
        self.grain          = (try? c.decodeIfPresent(GrainOp.self,          forKey: .grain))          ?? GrainOp()
        self.vignette       = (try? c.decodeIfPresent(VignetteOp.self,       forKey: .vignette))       ?? VignetteOp()
    }
}

/// Global color adjustments applied uniformly across the image, regardless of
/// hue band: hue rotation, saturation, vibrance (smart saturation), and
/// luminance. Pairs with the per-band HSL controls above — global goes first
/// in the pipeline, per-band tweaks the result.
public struct ColorOp: Codable, Equatable {
    public var hue: Int          // -180..180 degrees
    public var saturation: Int   // -100..100, multiplicative
    public var vibrance: Int     // -100..100, smart saturation
    public var luminance: Int    // -100..100, additive offset

    public init(hue: Int = 0, saturation: Int = 0, vibrance: Int = 0, luminance: Int = 0) {
        self.hue = hue
        self.saturation = saturation
        self.vibrance = vibrance
        self.luminance = luminance
    }
}

public struct CropOp: Codable, Equatable {
    public var enabled: Bool
    public var x: Double
    public var y: Double
    public var w: Double
    public var h: Double
    public var rotation: Double
    public var aspect: String

    public init(
        enabled: Bool = true,
        x: Double = 0.0,
        y: Double = 0.0,
        w: Double = 1.0,
        h: Double = 1.0,
        rotation: Double = 0.0,
        aspect: String = "free"
    ) {
        self.enabled = enabled
        self.x = x
        self.y = y
        self.w = w
        self.h = h
        self.rotation = rotation
        self.aspect = aspect
    }
}

public struct LensCorrectionOp: Codable, Equatable {
    public var enabled: Bool
    public var auto: Bool
    public var distortion: Double
    public var ca: Double
    public var vignette: Double

    public init(
        enabled: Bool = true,
        auto: Bool = true,
        distortion: Double = 1.0,
        ca: Double = 1.0,
        vignette: Double = 1.0
    ) {
        self.enabled = enabled
        self.auto = auto
        self.distortion = distortion
        self.ca = ca
        self.vignette = vignette
    }
}

public struct WhiteBalanceOp: Codable, Equatable {
    public static let asShot   = "asShot"
    public static let auto     = "auto"
    public static let custom   = "custom"

    public var mode: String
    public var temp: Int
    public var tint: Int

    /// Default mode is `asShot` so a freshly-created recipe is a true no-op
    /// against the source's recorded white balance. Switching to `custom`
    /// activates the temp/tint values.
    public init(mode: String = WhiteBalanceOp.asShot, temp: Int = 5500, tint: Int = 0) {
        self.mode = mode
        self.temp = temp
        self.tint = tint
    }
}

public struct ExposureOp: Codable, Equatable {
    public var ev: Double

    public init(ev: Double = 0.0) {
        self.ev = ev
    }
}

public struct ToneOp: Codable, Equatable {
    public var contrast: Int
    public var highlights: Int
    public var shadows: Int
    public var whites: Int
    public var blacks: Int
    public var highlightRecovery: Int

    public init(
        contrast: Int = 0,
        highlights: Int = 0,
        shadows: Int = 0,
        whites: Int = 0,
        blacks: Int = 0,
        highlightRecovery: Int = 0
    ) {
        self.contrast = contrast
        self.highlights = highlights
        self.shadows = shadows
        self.whites = whites
        self.blacks = blacks
        self.highlightRecovery = highlightRecovery
    }
}

public struct ToneCurveOp: Codable, Equatable {
    public var rgb: [[Double]]
    public var r: [[Double]]
    public var g: [[Double]]
    public var b: [[Double]]

    public static let identity: [[Double]] = [[0, 0], [1, 1]]

    public init(
        rgb: [[Double]] = identity,
        r: [[Double]] = identity,
        g: [[Double]] = identity,
        b: [[Double]] = identity
    ) {
        self.rgb = rgb
        self.r = r
        self.g = g
        self.b = b
    }
}

public struct HSLBand: Codable, Equatable {
    public var h: Int
    public var s: Int
    public var l: Int

    public init(h: Int = 0, s: Int = 0, l: Int = 0) {
        self.h = h
        self.s = s
        self.l = l
    }
}

public struct HSLOp: Codable, Equatable {
    public var red: HSLBand
    public var orange: HSLBand
    public var yellow: HSLBand
    public var green: HSLBand
    public var aqua: HSLBand
    public var blue: HSLBand
    public var purple: HSLBand
    public var magenta: HSLBand

    public init(
        red: HSLBand = .init(),
        orange: HSLBand = .init(),
        yellow: HSLBand = .init(),
        green: HSLBand = .init(),
        aqua: HSLBand = .init(),
        blue: HSLBand = .init(),
        purple: HSLBand = .init(),
        magenta: HSLBand = .init()
    ) {
        self.red = red
        self.orange = orange
        self.yellow = yellow
        self.green = green
        self.aqua = aqua
        self.blue = blue
        self.purple = purple
        self.magenta = magenta
    }
}

public struct GradingWheel: Codable, Equatable {
    public var hue: Int
    public var sat: Int
    public var lum: Int

    public init(hue: Int = 0, sat: Int = 0, lum: Int = 0) {
        self.hue = hue
        self.sat = sat
        self.lum = lum
    }
}

public struct ColorGradingOp: Codable, Equatable {
    public var shadows: GradingWheel
    public var midtones: GradingWheel
    public var highlights: GradingWheel
    public var global: GradingWheel
    public var blending: Int
    public var balance: Int

    public init(
        shadows: GradingWheel = .init(),
        midtones: GradingWheel = .init(),
        highlights: GradingWheel = .init(),
        global: GradingWheel = .init(),
        blending: Int = 50,
        balance: Int = 0
    ) {
        self.shadows = shadows
        self.midtones = midtones
        self.highlights = highlights
        self.global = global
        self.blending = blending
        self.balance = balance
    }
}

public struct BWMix: Codable, Equatable {
    public var red: Int
    public var orange: Int
    public var yellow: Int
    public var green: Int
    public var aqua: Int
    public var blue: Int
    public var purple: Int
    public var magenta: Int

    public init(
        red: Int = 0,
        orange: Int = 0,
        yellow: Int = 0,
        green: Int = 0,
        aqua: Int = 0,
        blue: Int = 0,
        purple: Int = 0,
        magenta: Int = 0
    ) {
        self.red = red
        self.orange = orange
        self.yellow = yellow
        self.green = green
        self.aqua = aqua
        self.blue = blue
        self.purple = purple
        self.magenta = magenta
    }
}

public struct BWOp: Codable, Equatable {
    public var enabled: Bool
    public var mix: BWMix

    public init(enabled: Bool = false, mix: BWMix = .init()) {
        self.enabled = enabled
        self.mix = mix
    }
}

public struct DetailOp: Codable, Equatable {
    public var sharpAmount: Int
    public var sharpRadius: Double
    public var sharpMasking: Int
    public var noiseLuma: Int
    public var noiseColor: Int

    public init(
        sharpAmount: Int = 30,
        sharpRadius: Double = 1.0,
        sharpMasking: Int = 0,
        noiseLuma: Int = 0,
        noiseColor: Int = 25
    ) {
        self.sharpAmount = sharpAmount
        self.sharpRadius = sharpRadius
        self.sharpMasking = sharpMasking
        self.noiseLuma = noiseLuma
        self.noiseColor = noiseColor
    }
}

public struct GrainOp: Equatable {
    // Six classic grain types. Each shapes the same per-pixel random
    // noise through type-specific blur + contrast settings.
    public static let typeFine       = "fine"        // modern digital, uniform
    public static let typeCubic      = "cubic"       // T-MAX-style sharp
    public static let typeTabular    = "tabular"     // anisotropic platelet
    public static let typeSilverRich = "silverRich"  // dense silver halide
    public static let typeSoft       = "soft"        // diffused portrait grain
    public static let typeHarsh      = "harsh"       // pushed-film grit

    public static let allTypes: [String] = [
        typeFine, typeCubic, typeTabular, typeSilverRich, typeSoft, typeHarsh
    ]

    public var amount: Int
    public var size: Int
    public var roughness: Int
    public var type: String

    public init(amount: Int = 0, size: Int = 25, roughness: Int = 50, type: String = GrainOp.typeFine) {
        self.amount = amount
        self.size = size
        self.roughness = roughness
        self.type = type
    }
}

extension GrainOp: Codable {
    private enum CodingKeys: String, CodingKey {
        case amount, size, roughness, type
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.amount    = (try? c.decodeIfPresent(Int.self, forKey: .amount))    ?? 0
        self.size      = (try? c.decodeIfPresent(Int.self, forKey: .size))      ?? 25
        self.roughness = (try? c.decodeIfPresent(Int.self, forKey: .roughness)) ?? 50
        self.type      = (try? c.decodeIfPresent(String.self, forKey: .type))   ?? GrainOp.typeCubic
    }
}

public struct VignetteOp: Codable, Equatable {
    public var amount: Int
    public var midpoint: Int
    public var feather: Int
    public var roundness: Int

    public init(amount: Int = 0, midpoint: Int = 50, feather: Int = 50, roundness: Int = 0) {
        self.amount = amount
        self.midpoint = midpoint
        self.feather = feather
        self.roundness = roundness
    }
}
