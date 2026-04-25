import Foundation

public struct Preset: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let category: String
    public let description: String
    public let operations: Operations

    public init(id: String, name: String, category: String, description: String = "", operations: Operations) {
        self.id = id
        self.name = name
        self.category = category
        self.description = description
        self.operations = operations
    }
}

/// 16 curated presets covering iconic street-photography looks. Numeric
/// values come from research on Lightroom/Capture One conventions for
/// Cinestill/Portra/Velvia/Tri-X-style emulations and contemporary
/// digital looks. Each preset preserves the user's crop and lens
/// correction when applied (see EditRecipe.apply(preset:)).
public enum BuiltinPresets {
    public static let all: [Preset] = [
        neutral,
        // B&W
        triXPush, moriyama, vivianMaier, parisHenriSilver, ericKimGrit,
        // Film
        tungstenNights, portraSkin, velviaSaturate, cinestill50D, kodakGold,
        // Color / Street / Cinematic
        memphisEggleston, leiterRain, polaroid600,
        lomochromePurple, tokyoNeonNoir
    ]

    public static let neutral = Preset(
        id: "neutral",
        name: "Neutral",
        category: "Reset",
        description: "Clear all adjustments.",
        operations: Operations()
    )

    // MARK: - B&W

    public static let triXPush = Preset(
        id: "tri-x-push",
        name: "Tri-X Push",
        category: "B&W",
        description: "Gritty B&W with crushed blacks and pushed highlights.",
        operations: build {
            $0.color.saturation = -100
            $0.tone.contrast = 45
            $0.tone.highlights = -30
            $0.tone.shadows = -25
            $0.tone.whites = 15
            $0.tone.blacks = -45
            $0.grain.amount = 55
            $0.hsl.red.l = 8
            $0.hsl.blue.l = -25
        }
    )

    public static let moriyama = Preset(
        id: "moriyama-are-bure-boke",
        name: "Moriyama",
        category: "B&W",
        description: "Daido Moriyama's are-bure-boke — smeared, grainy, brutal contrast.",
        operations: build {
            $0.color.saturation = -100
            $0.tone.contrast = 75
            $0.tone.highlights = -50
            $0.tone.shadows = -40
            $0.tone.whites = 40
            $0.tone.blacks = -60
            $0.grain.amount = 90
        }
    )

    public static let vivianMaier = Preset(
        id: "vivian-maier-rolleiflex",
        name: "Vivian Maier",
        category: "B&W",
        description: "Soft, square-format silver gelatin feel.",
        operations: build {
            $0.color.saturation = -100
            $0.tone.contrast = 8
            $0.tone.highlights = -15
            $0.tone.shadows = 12
            $0.tone.whites = -15
            $0.tone.blacks = -20
            $0.colorGrading.shadows.hue = 28
            $0.colorGrading.shadows.sat = 8
            $0.colorGrading.balance = -10
            $0.grain.amount = 25
            $0.hsl.red.l = 5
            $0.hsl.blue.l = -12
        }
    )

    public static let parisHenriSilver = Preset(
        id: "paris-henri-silver",
        name: "Paris Silver",
        category: "B&W",
        description: "Mid-grey classical B&W in the Cartier-Bresson tradition.",
        operations: build {
            $0.color.saturation = -100
            $0.tone.contrast = 22
            $0.tone.highlights = -10
            $0.tone.shadows = 8
            $0.tone.whites = -5
            $0.tone.blacks = -15
            $0.grain.amount = 18
            $0.hsl.red.l = 5
            $0.hsl.blue.l = -8
        }
    )

    public static let ericKimGrit = Preset(
        id: "eric-kim-grit",
        name: "Eric Kim Grit",
        category: "B&W",
        description: "Raw flash B&W: crushed contrast, deep blacks.",
        operations: build {
            $0.color.saturation = -100
            $0.tone.contrast = 60
            $0.tone.highlights = -40
            $0.tone.shadows = -30
            $0.tone.whites = 35
            $0.tone.blacks = -55
            $0.grain.amount = 70
            $0.hsl.red.l = -8
            $0.hsl.blue.l = -20
        }
    )

    // MARK: - Film

    public static let tungstenNights = Preset(
        id: "tungsten-nights",
        name: "Tungsten Nights",
        category: "Film",
        description: "Cinestill 800T halated reds, teal shadows, neon glow.",
        operations: build {
            $0.tone.contrast = 18
            $0.tone.highlights = -22
            $0.tone.shadows = 30
            $0.tone.whites = -10
            $0.tone.blacks = -18
            $0.color.saturation = -8
            $0.color.vibrance = 15
            $0.colorGrading.shadows.hue = 200
            $0.colorGrading.shadows.sat = 35
            $0.colorGrading.highlights.hue = 18
            $0.colorGrading.highlights.sat = 22
            $0.colorGrading.balance = -15
            $0.grain.amount = 35
            $0.hsl.red.s = 25
            $0.hsl.red.l = 10
            $0.hsl.blue.s = 30
        }
    )

    public static let portraSkin = Preset(
        id: "portra-skin",
        name: "Portra Skin",
        category: "Film",
        description: "Kodak Portra 400: creamy skin, pastel sky, low contrast.",
        operations: build {
            $0.tone.contrast = -8
            $0.tone.highlights = -15
            $0.tone.shadows = 22
            $0.tone.whites = -5
            $0.tone.blacks = -8
            $0.color.saturation = -12
            $0.color.vibrance = 22
            $0.colorGrading.shadows.hue = 30
            $0.colorGrading.shadows.sat = 12
            $0.colorGrading.highlights.hue = 38
            $0.colorGrading.highlights.sat = 18
            $0.colorGrading.balance = 5
            $0.grain.amount = 18
            $0.hsl.orange.s = -8
            $0.hsl.orange.l = 8
            $0.hsl.green.s = -15
        }
    )

    public static let velviaSaturate = Preset(
        id: "velvia-saturate",
        name: "Velvia",
        category: "Film",
        description: "Fuji Velvia 50: punchy reds and greens, deep blue sky.",
        operations: build {
            $0.tone.contrast = 28
            $0.tone.highlights = -8
            $0.tone.shadows = -12
            $0.tone.whites = 12
            $0.tone.blacks = -15
            $0.color.saturation = 28
            $0.color.vibrance = 15
            $0.colorGrading.shadows.hue = 220
            $0.colorGrading.shadows.sat = 15
            $0.colorGrading.highlights.hue = 35
            $0.colorGrading.highlights.sat = 10
            $0.grain.amount = 8
            $0.hsl.red.s = 20
            $0.hsl.green.s = 25
            $0.hsl.blue.s = 30
        }
    )

    public static let cinestill50D = Preset(
        id: "cinestill-50d",
        name: "Cinestill 50D",
        category: "Film",
        description: "Daylight 50D: clean, soft halation, pastel highlights.",
        operations: build {
            $0.tone.contrast = -5
            $0.tone.highlights = -20
            $0.tone.shadows = 15
            $0.tone.whites = -8
            $0.tone.blacks = -5
            $0.color.saturation = -8
            $0.color.vibrance = 12
            $0.colorGrading.shadows.hue = 35
            $0.colorGrading.shadows.sat = 15
            $0.colorGrading.highlights.hue = 30
            $0.colorGrading.highlights.sat = 15
            $0.grain.amount = 12
            $0.hsl.red.l = 12
            $0.hsl.blue.s = 8
        }
    )

    public static let kodakGold = Preset(
        id: "kodak-gold-sunday",
        name: "Kodak Gold",
        category: "Film",
        description: "Warm yellow-green nostalgic Sunday-afternoon look.",
        operations: build {
            $0.tone.contrast = 5
            $0.tone.highlights = -10
            $0.tone.shadows = 12
            $0.tone.whites = 0
            $0.tone.blacks = -8
            $0.color.saturation = -5
            $0.color.vibrance = 18
            $0.colorGrading.shadows.hue = 45
            $0.colorGrading.shadows.sat = 18
            $0.colorGrading.highlights.hue = 50
            $0.colorGrading.highlights.sat = 22
            $0.colorGrading.balance = 8
            $0.grain.amount = 20
            $0.hsl.yellow.s = 18
            $0.hsl.yellow.l = 10
            $0.hsl.green.l = 8
        }
    )

    // MARK: - Color / Street / Cinematic

    public static let memphisEggleston = Preset(
        id: "memphis-eggleston",
        name: "Eggleston",
        category: "Street",
        description: "William Eggleston warm Americana, faded reds.",
        operations: build {
            $0.tone.contrast = 12
            $0.tone.highlights = -20
            $0.tone.shadows = 18
            $0.tone.whites = -8
            $0.tone.blacks = -12
            $0.color.saturation = 8
            $0.color.vibrance = -5
            $0.colorGrading.shadows.hue = 25
            $0.colorGrading.shadows.sat = 20
            $0.colorGrading.highlights.hue = 42
            $0.colorGrading.highlights.sat = 15
            $0.colorGrading.balance = -8
            $0.grain.amount = 22
            $0.hsl.red.s = 18
            $0.hsl.red.l = -5
            $0.hsl.yellow.l = 10
        }
    )

    public static let leiterRain = Preset(
        id: "leiter-rain",
        name: "Leiter Rain",
        category: "Street",
        description: "Saul Leiter desaturated, muted color through wet glass.",
        operations: build {
            $0.tone.contrast = -15
            $0.tone.highlights = -25
            $0.tone.shadows = 15
            $0.tone.whites = -22
            $0.tone.blacks = -10
            $0.color.saturation = -45
            $0.color.vibrance = -15
            $0.colorGrading.shadows.hue = 210
            $0.colorGrading.shadows.sat = 22
            $0.colorGrading.highlights.hue = 25
            $0.colorGrading.highlights.sat = 8
            $0.colorGrading.balance = -20
            $0.grain.amount = 28
            $0.hsl.red.s = -30
            $0.hsl.blue.s = -20
            $0.hsl.green.s = -35
        }
    )

    public static let polaroid600 = Preset(
        id: "polaroid-600",
        name: "Polaroid 600",
        category: "Color",
        description: "Greenish cast, soft highlights, vignette feel.",
        operations: build {
            $0.tone.contrast = 5
            $0.tone.highlights = -30
            $0.tone.shadows = 25
            $0.tone.whites = -20
            $0.tone.blacks = -5
            $0.color.saturation = -15
            $0.color.vibrance = 8
            $0.colorGrading.shadows.hue = 90
            $0.colorGrading.shadows.sat = 18
            $0.colorGrading.highlights.hue = 60
            $0.colorGrading.highlights.sat = 12
            $0.colorGrading.balance = 10
            $0.grain.amount = 30
            $0.hsl.green.s = 12
            $0.hsl.blue.s = -18
            $0.hsl.red.l = -5
            $0.vignette.amount = -25
        }
    )

    public static let lomochromePurple = Preset(
        id: "lomochrome-purple",
        name: "Lomo Purple",
        category: "Cinematic",
        description: "Lomochrome Purple — green-to-magenta channel swap.",
        operations: build {
            $0.tone.contrast = 22
            $0.tone.highlights = -15
            $0.tone.shadows = -8
            $0.tone.whites = 8
            $0.tone.blacks = -18
            $0.color.saturation = 18
            $0.colorGrading.shadows.hue = 280
            $0.colorGrading.shadows.sat = 35
            $0.colorGrading.highlights.hue = 120
            $0.colorGrading.highlights.sat = 28
            $0.colorGrading.balance = -5
            $0.grain.amount = 25
            $0.hsl.green.s = 30
            $0.hsl.red.s = 15
        }
    )

    public static let tokyoNeonNoir = Preset(
        id: "tokyo-neon-noir",
        name: "Tokyo Noir",
        category: "Cinematic",
        description: "Saturated lows, magenta-cyan split, after-rain neon.",
        operations: build {
            $0.tone.contrast = 32
            $0.tone.highlights = -25
            $0.tone.shadows = -15
            $0.tone.whites = 15
            $0.tone.blacks = -30
            $0.color.saturation = 12
            $0.color.vibrance = 8
            $0.colorGrading.shadows.hue = 195
            $0.colorGrading.shadows.sat = 40
            $0.colorGrading.highlights.hue = 320
            $0.colorGrading.highlights.sat = 30
            $0.colorGrading.balance = -10
            $0.grain.amount = 32
            $0.hsl.blue.s = 25
            $0.hsl.red.s = 18
        }
    )

    private static func build(_ mutate: (inout Operations) -> Void) -> Operations {
        var ops = Operations()
        mutate(&ops)
        return ops
    }
}

extension EditRecipe {
    /// Apply a preset by replacing every operation EXCEPT crop and lens
    /// correction (those are per-image and shouldn't be overwritten by a
    /// look you bought from someone else's preset).
    public mutating func apply(preset: Preset) {
        var ops = preset.operations
        ops.crop = operations.crop
        ops.lensCorrection = operations.lensCorrection
        operations = ops
        modifiedAt = EditRecipe.now()
    }
}
