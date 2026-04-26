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
        kodakEktar, fujiProvia100F, fujiSuperia400, kodachrome64, agfaVista400,
        // Cinematic
        lomochromePurple, tokyoNeonNoir,
        wesAnderson, fincherDesat, bladeRunner2049, driveNeon, furyRoad,
        jokerSicko, hongKongNeon, deakinsGold,
        // Color
        polaroid600,
        sunsetGlow, popArt, crossProcess, fadedVintage,
        // Street
        memphisEggleston, leiterRain,
        joelMeyerowitz, alexWebb, fredHerzog, bruceDavidsonSubway
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

    public static let kodakEktar = Preset(
        id: "kodak-ektar-100",
        name: "Ektar 100",
        category: "Film",
        description: "Vivid pink-pushed reds, deep blues, fine-grain saturation.",
        operations: build {
            $0.tone.contrast = 22
            $0.tone.highlights = -10
            $0.tone.shadows = 5
            $0.tone.blacks = -10
            $0.color.saturation = 22
            $0.color.vibrance = 18
            $0.colorGrading.shadows.hue = 200
            $0.colorGrading.shadows.sat = 12
            $0.colorGrading.highlights.hue = 18
            $0.colorGrading.highlights.sat = 15
            $0.grain.amount = 8
            $0.hsl.red.h = 8
            $0.hsl.red.s = 22
            $0.hsl.green.s = 18
            $0.hsl.blue.s = 22
            $0.hsl.magenta.s = 15
        }
    )

    public static let fujiProvia100F = Preset(
        id: "fuji-provia-100f",
        name: "Provia 100F",
        category: "Film",
        description: "Clean, neutral Fuji slide film — slightly cool, restrained.",
        operations: build {
            $0.tone.contrast = 12
            $0.tone.highlights = -8
            $0.tone.shadows = 8
            $0.tone.blacks = -5
            $0.color.saturation = 5
            $0.color.vibrance = 12
            $0.colorGrading.shadows.hue = 210
            $0.colorGrading.shadows.sat = 10
            $0.colorGrading.highlights.hue = 200
            $0.colorGrading.highlights.sat = 5
            $0.colorGrading.balance = -5
            $0.grain.amount = 6
            $0.hsl.green.s = 10
            $0.hsl.blue.s = 12
        }
    )

    public static let fujiSuperia400 = Preset(
        id: "fuji-superia-400",
        name: "Superia 400",
        category: "Film",
        description: "Cool consumer film — green-shifted shadows, balanced reds.",
        operations: build {
            $0.tone.contrast = 15
            $0.tone.highlights = -12
            $0.tone.shadows = 18
            $0.tone.blacks = -8
            $0.color.saturation = 8
            $0.color.vibrance = 14
            $0.colorGrading.shadows.hue = 140
            $0.colorGrading.shadows.sat = 18
            $0.colorGrading.highlights.hue = 40
            $0.colorGrading.highlights.sat = 14
            $0.colorGrading.balance = -8
            $0.grain.amount = 18
            $0.hsl.green.s = 15
            $0.hsl.blue.s = 18
            $0.hsl.aqua.s = 12
        }
    )

    public static let kodachrome64 = Preset(
        id: "kodachrome-64",
        name: "Kodachrome 64",
        category: "Film",
        description: "Iconic rich reds and deep blues — National Geographic look.",
        operations: build {
            $0.tone.contrast = 25
            $0.tone.highlights = -12
            $0.tone.shadows = -5
            $0.tone.whites = 5
            $0.tone.blacks = -18
            $0.color.saturation = 18
            $0.color.vibrance = 12
            $0.colorGrading.shadows.hue = 220
            $0.colorGrading.shadows.sat = 15
            $0.colorGrading.highlights.hue = 35
            $0.colorGrading.highlights.sat = 18
            $0.colorGrading.balance = 5
            $0.grain.amount = 10
            $0.hsl.red.s = 25
            $0.hsl.red.l = -5
            $0.hsl.blue.s = 22
            $0.hsl.blue.l = -8
            $0.hsl.yellow.s = 18
        }
    )

    public static let agfaVista400 = Preset(
        id: "agfa-vista-400",
        name: "Agfa Vista",
        category: "Film",
        description: "Soft warm reds, lifted blacks — friendly casual film.",
        operations: build {
            $0.tone.contrast = -5
            $0.tone.highlights = -10
            $0.tone.shadows = 22
            $0.tone.whites = -5
            $0.tone.blacks = 12
            $0.color.saturation = -5
            $0.color.vibrance = 18
            $0.colorGrading.shadows.hue = 30
            $0.colorGrading.shadows.sat = 15
            $0.colorGrading.highlights.hue = 40
            $0.colorGrading.highlights.sat = 18
            $0.colorGrading.balance = 8
            $0.grain.amount = 22
            $0.hsl.red.s = 15
            $0.hsl.red.l = 5
            $0.hsl.orange.s = 12
            $0.hsl.orange.l = 5
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

    public static let joelMeyerowitz = Preset(
        id: "joel-meyerowitz",
        name: "Meyerowitz",
        category: "Street",
        description: "Bright color street pioneer — naturalistic, slightly warm.",
        operations: build {
            $0.tone.contrast = 12
            $0.tone.highlights = -15
            $0.tone.shadows = 15
            $0.tone.blacks = -8
            $0.color.saturation = 12
            $0.color.vibrance = 18
            $0.colorGrading.shadows.hue = 210
            $0.colorGrading.shadows.sat = 12
            $0.colorGrading.highlights.hue = 35
            $0.colorGrading.highlights.sat = 18
            $0.colorGrading.balance = 5
            $0.grain.amount = 15
            $0.hsl.red.s = 12
            $0.hsl.orange.s = 18
            $0.hsl.orange.l = 5
            $0.hsl.yellow.s = 14
            $0.hsl.blue.s = 12
        }
    )

    public static let alexWebb = Preset(
        id: "alex-webb",
        name: "Alex Webb",
        category: "Street",
        description: "Layered Magnum color — deep shadows, vivid mid-tones.",
        operations: build {
            $0.tone.contrast = 35
            $0.tone.highlights = -15
            $0.tone.shadows = -22
            $0.tone.blacks = -32
            $0.color.saturation = 25
            $0.color.vibrance = 18
            $0.colorGrading.shadows.hue = 220
            $0.colorGrading.shadows.sat = 22
            $0.colorGrading.highlights.hue = 25
            $0.colorGrading.highlights.sat = 22
            $0.colorGrading.balance = -8
            $0.grain.amount = 18
            $0.hsl.red.s = 22
            $0.hsl.orange.s = 18
            $0.hsl.blue.s = 28
            $0.hsl.yellow.s = 18
        }
    )

    public static let fredHerzog = Preset(
        id: "fred-herzog",
        name: "Fred Herzog",
        category: "Street",
        description: "Vancouver Kodachrome — saturated post-war color, neon signs.",
        operations: build {
            $0.tone.contrast = 22
            $0.tone.highlights = -12
            $0.tone.shadows = 8
            $0.tone.blacks = -12
            $0.color.saturation = 18
            $0.color.vibrance = 15
            $0.colorGrading.shadows.hue = 215
            $0.colorGrading.shadows.sat = 18
            $0.colorGrading.highlights.hue = 30
            $0.colorGrading.highlights.sat = 22
            $0.colorGrading.balance = 5
            $0.grain.amount = 18
            $0.hsl.red.s = 25
            $0.hsl.red.l = -3
            $0.hsl.blue.s = 22
            $0.hsl.yellow.s = 18
            $0.hsl.green.s = 12
        }
    )

    public static let bruceDavidsonSubway = Preset(
        id: "bruce-davidson-subway",
        name: "Davidson Subway",
        category: "Street",
        description: "Gritty 1980s NYC — harsh flash, deep shadows, neon dirt.",
        operations: build {
            $0.tone.contrast = 32
            $0.tone.highlights = -25
            $0.tone.shadows = -15
            $0.tone.blacks = -28
            $0.color.saturation = 18
            $0.color.vibrance = 12
            $0.colorGrading.shadows.hue = 240
            $0.colorGrading.shadows.sat = 22
            $0.colorGrading.shadows.lum = -3
            $0.colorGrading.highlights.hue = 15
            $0.colorGrading.highlights.sat = 25
            $0.colorGrading.balance = -10
            $0.grain.amount = 35
            $0.hsl.red.s = 22
            $0.hsl.red.l = -5
            $0.hsl.orange.s = 18
            $0.hsl.blue.s = 18
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

    public static let sunsetGlow = Preset(
        id: "sunset-glow",
        name: "Sunset Glow",
        category: "Color",
        description: "Golden hour warmth — peachy highlights, amber shadows.",
        operations: build {
            $0.tone.contrast = 8
            $0.tone.highlights = -15
            $0.tone.shadows = 12
            $0.tone.blacks = -5
            $0.color.saturation = 12
            $0.color.vibrance = 22
            $0.colorGrading.shadows.hue = 25
            $0.colorGrading.shadows.sat = 22
            $0.colorGrading.highlights.hue = 35
            $0.colorGrading.highlights.sat = 28
            $0.colorGrading.balance = 12
            $0.grain.amount = 8
            $0.hsl.red.s = 15
            $0.hsl.orange.s = 25
            $0.hsl.orange.l = 10
            $0.hsl.yellow.s = 22
            $0.hsl.yellow.l = 8
        }
    )

    public static let popArt = Preset(
        id: "pop-art",
        name: "Pop Art",
        category: "Color",
        description: "Hyper-saturated primaries — Warhol-bright comic-book color.",
        operations: build {
            $0.tone.contrast = 35
            $0.tone.highlights = -10
            $0.tone.shadows = -5
            $0.tone.whites = 12
            $0.tone.blacks = -22
            $0.color.saturation = 45
            $0.color.vibrance = 25
            $0.colorGrading.shadows.hue = 270
            $0.colorGrading.shadows.sat = 15
            $0.colorGrading.highlights.hue = 50
            $0.colorGrading.highlights.sat = 22
            $0.grain.amount = 5
            $0.hsl.red.s = 32
            $0.hsl.blue.s = 32
            $0.hsl.yellow.s = 32
            $0.hsl.green.s = 30
            $0.hsl.magenta.s = 28
        }
    )

    public static let crossProcess = Preset(
        id: "cross-process",
        name: "Cross Process",
        category: "Color",
        description: "C-41 in E-6 chemistry — punchy contrast, shifted casts.",
        operations: build {
            $0.tone.contrast = 28
            $0.tone.highlights = -18
            $0.tone.shadows = 22
            $0.tone.whites = 12
            $0.tone.blacks = -25
            $0.color.saturation = 22
            $0.color.vibrance = 12
            $0.colorGrading.shadows.hue = 220
            $0.colorGrading.shadows.sat = 30
            $0.colorGrading.highlights.hue = 60
            $0.colorGrading.highlights.sat = 28
            $0.colorGrading.balance = 8
            $0.grain.amount = 18
            $0.hsl.green.h = 12
            $0.hsl.green.s = 25
            $0.hsl.blue.s = 22
            $0.hsl.yellow.s = 18
        }
    )

    public static let fadedVintage = Preset(
        id: "faded-vintage",
        name: "Faded Vintage",
        category: "Color",
        description: "Washed pastel colors, lifted blacks — old print look.",
        operations: build {
            $0.tone.contrast = -22
            $0.tone.highlights = -22
            $0.tone.shadows = 30
            $0.tone.whites = -15
            $0.tone.blacks = 32
            $0.color.saturation = -25
            $0.color.vibrance = 8
            $0.colorGrading.shadows.hue = 30
            $0.colorGrading.shadows.sat = 18
            $0.colorGrading.highlights.hue = 200
            $0.colorGrading.highlights.sat = 12
            $0.colorGrading.balance = -8
            $0.grain.amount = 28
            $0.hsl.red.s = -12
            $0.hsl.blue.s = -20
            $0.hsl.green.s = -18
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

    public static let wesAnderson = Preset(
        id: "wes-anderson",
        name: "Wes Anderson",
        category: "Cinematic",
        description: "Pastel symmetric — peach highlights, butter shadows, low contrast.",
        operations: build {
            $0.tone.contrast = -10
            $0.tone.highlights = -15
            $0.tone.shadows = 22
            $0.tone.whites = -8
            $0.tone.blacks = 12
            $0.color.saturation = -8
            $0.color.vibrance = 8
            $0.colorGrading.shadows.hue = 30
            $0.colorGrading.shadows.sat = 22
            $0.colorGrading.highlights.hue = 42
            $0.colorGrading.highlights.sat = 28
            $0.colorGrading.balance = 8
            $0.grain.amount = 12
            $0.hsl.yellow.s = 18
            $0.hsl.yellow.l = 10
            $0.hsl.orange.s = 15
            $0.hsl.orange.l = 8
        }
    )

    public static let fincherDesat = Preset(
        id: "fincher-desat",
        name: "Fincher",
        category: "Cinematic",
        description: "Desaturated greens, cool sickly shadows — Se7en / Zodiac.",
        operations: build {
            $0.tone.contrast = 28
            $0.tone.highlights = -25
            $0.tone.shadows = -12
            $0.tone.whites = 8
            $0.tone.blacks = -28
            $0.color.saturation = -32
            $0.color.vibrance = -10
            $0.colorGrading.shadows.hue = 195
            $0.colorGrading.shadows.sat = 25
            $0.colorGrading.shadows.lum = -5
            $0.colorGrading.highlights.hue = 180
            $0.colorGrading.highlights.sat = 12
            $0.colorGrading.balance = -15
            $0.grain.amount = 18
            $0.hsl.green.s = -18
            $0.hsl.green.l = -10
            $0.hsl.yellow.s = -22
        }
    )

    public static let bladeRunner2049 = Preset(
        id: "blade-runner-2049",
        name: "Blade Runner 2049",
        category: "Cinematic",
        description: "Amber/teal duotone, smoky atmosphere — Roger Deakins palette.",
        operations: build {
            $0.tone.contrast = 22
            $0.tone.highlights = -20
            $0.tone.shadows = 15
            $0.tone.blacks = -15
            $0.color.saturation = -5
            $0.color.vibrance = 15
            $0.colorGrading.shadows.hue = 195
            $0.colorGrading.shadows.sat = 38
            $0.colorGrading.highlights.hue = 30
            $0.colorGrading.highlights.sat = 32
            $0.colorGrading.balance = 8
            $0.grain.amount = 22
            $0.hsl.orange.s = 20
            $0.hsl.orange.l = 8
            $0.hsl.blue.s = 22
        }
    )

    public static let driveNeon = Preset(
        id: "drive-neon",
        name: "Drive (2011)",
        category: "Cinematic",
        description: "Magenta/cyan split, neon noir — synthwave Refn palette.",
        operations: build {
            $0.tone.contrast = 30
            $0.tone.highlights = -22
            $0.tone.shadows = -10
            $0.tone.blacks = -22
            $0.color.saturation = 12
            $0.color.vibrance = 10
            $0.colorGrading.shadows.hue = 305
            $0.colorGrading.shadows.sat = 32
            $0.colorGrading.highlights.hue = 180
            $0.colorGrading.highlights.sat = 25
            $0.colorGrading.balance = -8
            $0.grain.amount = 25
            $0.hsl.blue.s = 22
            $0.hsl.magenta.s = 22
            $0.hsl.red.s = 18
        }
    )

    public static let furyRoad = Preset(
        id: "fury-road",
        name: "Fury Road",
        category: "Cinematic",
        description: "Hyper-saturated orange/teal desert apocalypse.",
        operations: build {
            $0.tone.contrast = 35
            $0.tone.highlights = -15
            $0.tone.shadows = -8
            $0.tone.whites = 10
            $0.tone.blacks = -28
            $0.color.saturation = 28
            $0.color.vibrance = 18
            $0.colorGrading.shadows.hue = 200
            $0.colorGrading.shadows.sat = 42
            $0.colorGrading.highlights.hue = 25
            $0.colorGrading.highlights.sat = 38
            $0.colorGrading.balance = 5
            $0.grain.amount = 8
            $0.hsl.orange.s = 32
            $0.hsl.orange.l = 5
            $0.hsl.blue.s = 30
            $0.hsl.blue.l = -5
            $0.hsl.yellow.s = 22
        }
    )

    public static let jokerSicko = Preset(
        id: "joker-sicko",
        name: "Joker (2019)",
        category: "Cinematic",
        description: "Sickly greenish teal, anxious mood — Phillips' Gotham.",
        operations: build {
            $0.tone.contrast = 28
            $0.tone.highlights = -25
            $0.tone.shadows = 8
            $0.tone.blacks = -22
            $0.color.saturation = -18
            $0.color.vibrance = -5
            $0.colorGrading.shadows.hue = 160
            $0.colorGrading.shadows.sat = 28
            $0.colorGrading.shadows.lum = -3
            $0.colorGrading.highlights.hue = 150
            $0.colorGrading.highlights.sat = 18
            $0.colorGrading.balance = -10
            $0.grain.amount = 28
            $0.hsl.green.s = 18
            $0.hsl.green.l = 5
            $0.hsl.yellow.s = -12
        }
    )

    public static let hongKongNeon = Preset(
        id: "hong-kong-neon",
        name: "Hong Kong Neon",
        category: "Cinematic",
        description: "Wong Kar-wai / Doyle — vivid greens and reds, rain-soaked.",
        operations: build {
            $0.tone.contrast = 25
            $0.tone.highlights = -22
            $0.tone.shadows = 12
            $0.tone.blacks = -18
            $0.color.saturation = 18
            $0.color.vibrance = 15
            $0.colorGrading.shadows.hue = 180
            $0.colorGrading.shadows.sat = 28
            $0.colorGrading.highlights.hue = 15
            $0.colorGrading.highlights.sat = 25
            $0.colorGrading.balance = -5
            $0.grain.amount = 25
            $0.hsl.red.s = 22
            $0.hsl.red.l = 5
            $0.hsl.green.s = 25
            $0.hsl.green.l = 8
            $0.hsl.aqua.s = 20
        }
    )

    public static let deakinsGold = Preset(
        id: "deakins-gold",
        name: "Deakins Gold",
        category: "Cinematic",
        description: "Warm naturalistic golden hour — Skyfall, 1917, No Country.",
        operations: build {
            $0.tone.contrast = 22
            $0.tone.highlights = -20
            $0.tone.shadows = 8
            $0.tone.blacks = -15
            $0.color.saturation = 5
            $0.color.vibrance = 18
            $0.colorGrading.shadows.hue = 30
            $0.colorGrading.shadows.sat = 18
            $0.colorGrading.highlights.hue = 40
            $0.colorGrading.highlights.sat = 25
            $0.colorGrading.balance = 8
            $0.grain.amount = 12
            $0.hsl.red.s = 15
            $0.hsl.orange.s = 18
            $0.hsl.orange.l = 5
            $0.hsl.yellow.l = 8
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
