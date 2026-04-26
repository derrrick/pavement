import Foundation

public struct Preset: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let category: String
    public let description: String
    public let recommendedAmount: Double
    public let operations: Operations

    public init(
        id: String,
        name: String,
        category: String,
        description: String = "",
        recommendedAmount: Double? = nil,
        operations: Operations
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.description = description
        self.recommendedAmount = recommendedAmount ?? Self.recommendedAmount(for: operations, category: category)
        self.operations = operations
    }

    private static func recommendedAmount(for operations: Operations, category: String) -> Double {
        if category == "Reset" || category == "B&W" || operations.color.saturation <= -95 {
            return 1.0
        }

        let toneWeight = abs(operations.tone.contrast)
            + abs(operations.tone.highlights) / 2
            + abs(operations.tone.shadows) / 2
            + abs(operations.tone.whites) / 2
            + abs(operations.tone.blacks) / 2
        let colorWeight = abs(operations.color.saturation)
            + abs(operations.color.vibrance) / 2
            + operations.colorGrading.shadows.sat
            + operations.colorGrading.midtones.sat
            + operations.colorGrading.highlights.sat
        let weight = Double(toneWeight + colorWeight + operations.grain.amount / 2)

        switch weight {
        case 0..<70: return 0.95
        case 70..<115: return 0.88
        case 115..<165: return 0.80
        default: return 0.72
        }
    }
}

/// 72 curated presets across 6 categories (B&W, Film, Cinematic, Color,
/// Street, Landscape) — 12 per category. Numeric values come from
/// research on Lightroom/Capture One conventions for film-stock and
/// look emulation. Each preset preserves the user's crop and lens
/// correction when applied (see EditRecipe.apply(preset:)).
public enum BuiltinPresets {
    public static let all: [Preset] = [
        neutral,
        // B&W (12)
        triXPush, moriyama, vivianMaier, parisHenriSilver, ericKimGrit,
        anselZone, highKeyBW, lowKeyBW, platinumPalladium,
        documentaryReportage, architectureBW, classicWeddingBW,
        // Film (12)
        tungstenNights, portraSkin, velviaSaturate, cinestill50D, kodakGold,
        kodakEktar, fujiProvia100F, fujiSuperia400, kodachrome64, agfaVista400,
        portra160, fujiPro400H,
        // Cinematic (12)
        lomochromePurple, tokyoNeonNoir,
        wesAnderson, fincherDesat, bladeRunner2049, driveNeon, furyRoad,
        jokerSicko, hongKongNeon, deakinsGold,
        moonlightJenkins, godfatherWillis,
        // Color (12)
        polaroid600, sunsetGlow, popArt, crossProcess, fadedVintage,
        tealOrangeHollywood, midnightBlue, coralReef, jadeMint,
        amberGlow, pastelDream, vibrantSummer,
        // Street (12)
        memphisEggleston, leiterRain,
        joelMeyerowitz, alexWebb, fredHerzog, bruceDavidsonSubway,
        martinParr, stephenShore, winogrand, nanGoldin, robertFrank, fanHo,
        // Landscape (12)
        anselMountains, peterLikDramatic, mistyMorning, goldenVista, blueHour,
        autumnVivid, snowscape, tropicalParadise, desertRed,
        forestEmerald, michaelKennaQuiet, nickBrandtAfrica
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

    // MARK: - B&W additions (7)

    public static let anselZone = Preset(
        id: "ansel-zone",
        name: "Ansel Zone",
        category: "B&W",
        description: "Adams Zone System — full tonal range, dramatic skies via blue darken.",
        operations: build {
            $0.color.saturation = -100
            $0.tone.contrast = 32
            $0.tone.highlights = 8
            $0.tone.shadows = -5
            $0.tone.whites = 15
            $0.tone.blacks = -28
            $0.grain.amount = 12
            $0.hsl.red.l = 5       // skin/rocks lift
            $0.hsl.blue.l = -45    // dark dramatic skies
            $0.hsl.aqua.l = -25
        }
    )

    public static let highKeyBW = Preset(
        id: "high-key-bw",
        name: "High Key",
        category: "B&W",
        description: "Bright airy whites, soft shadows — fashion / wedding feel.",
        operations: build {
            $0.color.saturation = -100
            $0.tone.contrast = -15
            $0.tone.highlights = 25
            $0.tone.shadows = 35
            $0.tone.whites = 28
            $0.tone.blacks = 12
            $0.grain.amount = 8
        }
    )

    public static let lowKeyBW = Preset(
        id: "low-key-bw",
        name: "Low Key",
        category: "B&W",
        description: "Dark moody portrait — deep shadows, sculpted highlights.",
        operations: build {
            $0.color.saturation = -100
            $0.tone.contrast = 45
            $0.tone.highlights = -15
            $0.tone.shadows = -45
            $0.tone.whites = 8
            $0.tone.blacks = -55
            $0.grain.amount = 18
            $0.hsl.red.l = 10  // skin retains structure
        }
    )

    public static let platinumPalladium = Preset(
        id: "platinum-palladium",
        name: "Platinum",
        category: "B&W",
        description: "Warm-toned alt-process print look — soft, long tonal range.",
        operations: build {
            $0.color.saturation = -100
            $0.tone.contrast = 12
            $0.tone.highlights = -8
            $0.tone.shadows = 18
            $0.tone.whites = -10
            $0.tone.blacks = -8
            $0.colorGrading.shadows.hue = 35
            $0.colorGrading.shadows.sat = 18
            $0.colorGrading.highlights.hue = 40
            $0.colorGrading.highlights.sat = 12
            $0.colorGrading.balance = 5
            $0.grain.amount = 15
        }
    )

    public static let documentaryReportage = Preset(
        id: "documentary-reportage",
        name: "Reportage",
        category: "B&W",
        description: "Press-photo neutral B&W — moderate contrast, full midtones.",
        operations: build {
            $0.color.saturation = -100
            $0.tone.contrast = 25
            $0.tone.highlights = -12
            $0.tone.shadows = 5
            $0.tone.whites = 5
            $0.tone.blacks = -22
            $0.grain.amount = 22
            $0.hsl.red.l = 5
            $0.hsl.blue.l = -15
        }
    )

    public static let architectureBW = Preset(
        id: "architecture-bw",
        name: "Architecture",
        category: "B&W",
        description: "Crisp B&W for buildings — strong micro-contrast, clean whites.",
        operations: build {
            $0.color.saturation = -100
            $0.tone.contrast = 38
            $0.tone.highlights = -18
            $0.tone.shadows = -10
            $0.tone.whites = 22
            $0.tone.blacks = -32
            $0.detail.sharpAmount = 55
            $0.grain.amount = 5
            $0.hsl.blue.l = -30   // sky separation
        }
    )

    public static let classicWeddingBW = Preset(
        id: "classic-wedding-bw",
        name: "Classic Wedding",
        category: "B&W",
        description: "Soft creamy B&W — flattering for skin, gentle on highlights.",
        operations: build {
            $0.color.saturation = -100
            $0.tone.contrast = 5
            $0.tone.highlights = -22
            $0.tone.shadows = 22
            $0.tone.whites = -8
            $0.tone.blacks = -12
            $0.grain.amount = 14
            $0.hsl.red.l = 12    // skin glow
            $0.hsl.orange.l = 10
        }
    )

    // MARK: - Film additions (2)

    public static let portra160 = Preset(
        id: "portra-160",
        name: "Portra 160",
        category: "Film",
        description: "Lower-ISO Portra — even creamier skin, gentler grain than 400.",
        operations: build {
            $0.tone.contrast = -12
            $0.tone.highlights = -18
            $0.tone.shadows = 25
            $0.tone.whites = -8
            $0.tone.blacks = -5
            $0.color.saturation = -15
            $0.color.vibrance = 18
            $0.colorGrading.shadows.hue = 35
            $0.colorGrading.shadows.sat = 10
            $0.colorGrading.highlights.hue = 42
            $0.colorGrading.highlights.sat = 15
            $0.colorGrading.balance = 8
            $0.grain.amount = 10
            $0.hsl.orange.s = -10
            $0.hsl.orange.l = 10
            $0.hsl.green.s = -18
        }
    )

    public static let fujiPro400H = Preset(
        id: "fuji-pro-400h",
        name: "Pro 400H",
        category: "Film",
        description: "Cool pastel wedding film — minty greens, airy highlights.",
        operations: build {
            $0.tone.contrast = -8
            $0.tone.highlights = -22
            $0.tone.shadows = 22
            $0.tone.whites = -12
            $0.tone.blacks = -5
            $0.color.saturation = -8
            $0.color.vibrance = 15
            $0.colorGrading.shadows.hue = 160
            $0.colorGrading.shadows.sat = 12
            $0.colorGrading.highlights.hue = 180
            $0.colorGrading.highlights.sat = 8
            $0.colorGrading.balance = -5
            $0.grain.amount = 12
            $0.hsl.green.s = -12
            $0.hsl.aqua.s = 12
            $0.hsl.blue.s = 8
        }
    )

    // MARK: - Cinematic additions (2)

    public static let moonlightJenkins = Preset(
        id: "moonlight-jenkins",
        name: "Moonlight",
        category: "Cinematic",
        description: "Magenta-violet beach scenes — Barry Jenkins / James Laxton.",
        operations: build {
            $0.tone.contrast = 18
            $0.tone.highlights = -20
            $0.tone.shadows = 12
            $0.tone.blacks = -22
            $0.color.saturation = 8
            $0.color.vibrance = 18
            $0.colorGrading.shadows.hue = 290
            $0.colorGrading.shadows.sat = 32
            $0.colorGrading.highlights.hue = 320
            $0.colorGrading.highlights.sat = 22
            $0.colorGrading.balance = -5
            $0.grain.amount = 22
            $0.hsl.red.s = 18
            $0.hsl.magenta.s = 25
            $0.hsl.blue.s = 18
        }
    )

    public static let godfatherWillis = Preset(
        id: "godfather-willis",
        name: "Godfather",
        category: "Cinematic",
        description: "Gordon Willis sepia warmth — deep shadows, amber/gold highlights.",
        operations: build {
            $0.tone.contrast = 28
            $0.tone.highlights = -12
            $0.tone.shadows = -22
            $0.tone.blacks = -38
            $0.color.saturation = -22
            $0.color.vibrance = 5
            $0.colorGrading.shadows.hue = 30
            $0.colorGrading.shadows.sat = 22
            $0.colorGrading.shadows.lum = -3
            $0.colorGrading.highlights.hue = 38
            $0.colorGrading.highlights.sat = 32
            $0.colorGrading.balance = 12
            $0.grain.amount = 20
            $0.hsl.orange.s = 18
            $0.hsl.orange.l = 5
            $0.hsl.yellow.l = 8
        }
    )

    // MARK: - Color additions (7)

    public static let tealOrangeHollywood = Preset(
        id: "teal-orange-hollywood",
        name: "Teal/Orange",
        category: "Color",
        description: "Classic complementary look — warm skin against cool surroundings.",
        operations: build {
            $0.tone.contrast = 25
            $0.tone.highlights = -15
            $0.tone.shadows = 8
            $0.tone.blacks = -18
            $0.color.saturation = 12
            $0.color.vibrance = 18
            $0.colorGrading.shadows.hue = 195
            $0.colorGrading.shadows.sat = 32
            $0.colorGrading.highlights.hue = 25
            $0.colorGrading.highlights.sat = 30
            $0.colorGrading.balance = 5
            $0.grain.amount = 10
            $0.hsl.orange.s = 22
            $0.hsl.orange.l = 8
            $0.hsl.aqua.s = 22
            $0.hsl.blue.s = 18
        }
    )

    public static let midnightBlue = Preset(
        id: "midnight-blue",
        name: "Midnight Blue",
        category: "Color",
        description: "Deep moody blue — twilight cool, lifted shadows for atmosphere.",
        operations: build {
            $0.tone.contrast = 18
            $0.tone.highlights = -22
            $0.tone.shadows = 18
            $0.tone.blacks = -10
            $0.color.saturation = -10
            $0.color.vibrance = 15
            $0.colorGrading.shadows.hue = 220
            $0.colorGrading.shadows.sat = 38
            $0.colorGrading.highlights.hue = 215
            $0.colorGrading.highlights.sat = 22
            $0.colorGrading.balance = -12
            $0.grain.amount = 15
            $0.hsl.blue.s = 25
            $0.hsl.blue.l = -8
            $0.hsl.purple.s = 22
        }
    )

    public static let coralReef = Preset(
        id: "coral-reef",
        name: "Coral Reef",
        category: "Color",
        description: "Tropical pinks and oranges — sun-bleached coral palette.",
        operations: build {
            $0.tone.contrast = 8
            $0.tone.highlights = -15
            $0.tone.shadows = 18
            $0.tone.blacks = -8
            $0.color.saturation = 8
            $0.color.vibrance = 22
            $0.colorGrading.shadows.hue = 18
            $0.colorGrading.shadows.sat = 25
            $0.colorGrading.highlights.hue = 20
            $0.colorGrading.highlights.sat = 28
            $0.colorGrading.balance = 12
            $0.grain.amount = 10
            $0.hsl.red.s = 18
            $0.hsl.orange.s = 28
            $0.hsl.orange.l = 10
            $0.hsl.aqua.s = 12
        }
    )

    public static let jadeMint = Preset(
        id: "jade-mint",
        name: "Jade Mint",
        category: "Color",
        description: "Cool mint pastels — soft greens, milky highlights.",
        operations: build {
            $0.tone.contrast = -10
            $0.tone.highlights = -22
            $0.tone.shadows = 25
            $0.tone.whites = -10
            $0.tone.blacks = 5
            $0.color.saturation = -15
            $0.color.vibrance = 12
            $0.colorGrading.shadows.hue = 150
            $0.colorGrading.shadows.sat = 20
            $0.colorGrading.highlights.hue = 165
            $0.colorGrading.highlights.sat = 18
            $0.colorGrading.balance = -8
            $0.grain.amount = 12
            $0.hsl.green.s = -8
            $0.hsl.aqua.s = 22
            $0.hsl.aqua.l = 12
        }
    )

    public static let amberGlow = Preset(
        id: "amber-glow",
        name: "Amber Glow",
        category: "Color",
        description: "Honey-gold warmth across the frame — cozy interior lighting.",
        operations: build {
            $0.tone.contrast = 12
            $0.tone.highlights = -18
            $0.tone.shadows = 18
            $0.tone.blacks = -15
            $0.color.saturation = 10
            $0.color.vibrance = 22
            $0.colorGrading.shadows.hue = 35
            $0.colorGrading.shadows.sat = 30
            $0.colorGrading.highlights.hue = 45
            $0.colorGrading.highlights.sat = 32
            $0.colorGrading.balance = 15
            $0.grain.amount = 12
            $0.hsl.red.s = 12
            $0.hsl.orange.s = 22
            $0.hsl.orange.l = 8
            $0.hsl.yellow.s = 18
            $0.hsl.yellow.l = 5
        }
    )

    public static let pastelDream = Preset(
        id: "pastel-dream",
        name: "Pastel Dream",
        category: "Color",
        description: "Soft dreamy pastels — desaturated, slightly hazy, romantic.",
        operations: build {
            $0.tone.contrast = -22
            $0.tone.highlights = -25
            $0.tone.shadows = 35
            $0.tone.whites = -12
            $0.tone.blacks = 28
            $0.color.saturation = -38
            $0.color.vibrance = 12
            $0.colorGrading.shadows.hue = 320
            $0.colorGrading.shadows.sat = 18
            $0.colorGrading.highlights.hue = 35
            $0.colorGrading.highlights.sat = 15
            $0.colorGrading.balance = 0
            $0.grain.amount = 18
        }
    )

    public static let vibrantSummer = Preset(
        id: "vibrant-summer",
        name: "Vibrant Summer",
        category: "Color",
        description: "Punchy bright summer colors — saturated greens, pop blues.",
        operations: build {
            $0.tone.contrast = 22
            $0.tone.highlights = -8
            $0.tone.shadows = 5
            $0.tone.whites = 8
            $0.tone.blacks = -15
            $0.color.saturation = 25
            $0.color.vibrance = 18
            $0.colorGrading.shadows.hue = 215
            $0.colorGrading.shadows.sat = 12
            $0.colorGrading.highlights.hue = 50
            $0.colorGrading.highlights.sat = 18
            $0.grain.amount = 6
            $0.hsl.red.s = 18
            $0.hsl.orange.s = 18
            $0.hsl.yellow.s = 22
            $0.hsl.green.s = 25
            $0.hsl.blue.s = 22
        }
    )

    // MARK: - Street additions (6)

    public static let martinParr = Preset(
        id: "martin-parr",
        name: "Martin Parr",
        category: "Street",
        description: "Hyper-saturated British seaside — flash-lit kitsch documentary.",
        operations: build {
            $0.tone.contrast = 35
            $0.tone.highlights = -12
            $0.tone.shadows = -5
            $0.tone.whites = 15
            $0.tone.blacks = -22
            $0.color.saturation = 38
            $0.color.vibrance = 22
            $0.colorGrading.shadows.hue = 220
            $0.colorGrading.shadows.sat = 18
            $0.colorGrading.highlights.hue = 50
            $0.colorGrading.highlights.sat = 20
            $0.grain.amount = 12
            $0.hsl.red.s = 32
            $0.hsl.orange.s = 30
            $0.hsl.yellow.s = 30
            $0.hsl.blue.s = 30
            $0.hsl.magenta.s = 28
        }
    )

    public static let stephenShore = Preset(
        id: "stephen-shore",
        name: "Stephen Shore",
        category: "Street",
        description: "Quiet uncommon places — flat light, gentle color, 1970s color print.",
        operations: build {
            $0.tone.contrast = 5
            $0.tone.highlights = -18
            $0.tone.shadows = 18
            $0.tone.whites = -8
            $0.tone.blacks = -8
            $0.color.saturation = -8
            $0.color.vibrance = 5
            $0.colorGrading.shadows.hue = 28
            $0.colorGrading.shadows.sat = 15
            $0.colorGrading.highlights.hue = 42
            $0.colorGrading.highlights.sat = 12
            $0.colorGrading.balance = 5
            $0.grain.amount = 18
            $0.hsl.red.s = 8
            $0.hsl.orange.l = 5
            $0.hsl.green.s = -8
        }
    )

    public static let winogrand = Preset(
        id: "garry-winogrand",
        name: "Winogrand",
        category: "Street",
        description: "High-contrast wide-angle B&W documentary — pioneering street.",
        operations: build {
            $0.color.saturation = -100
            $0.tone.contrast = 42
            $0.tone.highlights = -25
            $0.tone.shadows = -18
            $0.tone.whites = 18
            $0.tone.blacks = -42
            $0.grain.amount = 32
            $0.hsl.red.l = 5
            $0.hsl.blue.l = -22
        }
    )

    public static let nanGoldin = Preset(
        id: "nan-goldin",
        name: "Nan Goldin",
        category: "Street",
        description: "Intimate flash color — pushed reds, gritty interiors, raw.",
        operations: build {
            $0.tone.contrast = 22
            $0.tone.highlights = -15
            $0.tone.shadows = -12
            $0.tone.blacks = -25
            $0.color.saturation = 18
            $0.color.vibrance = 5
            $0.colorGrading.shadows.hue = 250
            $0.colorGrading.shadows.sat = 18
            $0.colorGrading.highlights.hue = 15
            $0.colorGrading.highlights.sat = 25
            $0.colorGrading.balance = -5
            $0.grain.amount = 32
            $0.hsl.red.s = 28
            $0.hsl.red.l = 8
            $0.hsl.orange.s = 22
        }
    )

    public static let robertFrank = Preset(
        id: "robert-frank",
        name: "Robert Frank",
        category: "Street",
        description: "The Americans — somber documentary B&W, lifted blacks, dust feel.",
        operations: build {
            $0.color.saturation = -100
            $0.tone.contrast = 8
            $0.tone.highlights = -15
            $0.tone.shadows = 22
            $0.tone.whites = -12
            $0.tone.blacks = 8
            $0.grain.amount = 38
            $0.hsl.red.l = 0
            $0.hsl.blue.l = -10
        }
    )

    public static let fanHo = Preset(
        id: "fan-ho",
        name: "Fan Ho",
        category: "Street",
        description: "Hong Kong light & shadow B&W — geometric beams, dramatic chiaroscuro.",
        operations: build {
            $0.color.saturation = -100
            $0.tone.contrast = 38
            $0.tone.highlights = -15
            $0.tone.shadows = -32
            $0.tone.whites = 22
            $0.tone.blacks = -40
            $0.grain.amount = 18
            $0.hsl.red.l = 8
            $0.hsl.blue.l = -25
        }
    )

    // MARK: - Landscape (12 — new category)

    public static let anselMountains = Preset(
        id: "ansel-mountains",
        name: "Ansel Mountains",
        category: "Landscape",
        description: "Adams Yosemite — dramatic sky darken, glowing peaks, full tonal range.",
        operations: build {
            $0.color.saturation = -100
            $0.tone.contrast = 38
            $0.tone.highlights = 12
            $0.tone.shadows = -8
            $0.tone.whites = 22
            $0.tone.blacks = -32
            $0.grain.amount = 10
            $0.hsl.red.l = 8
            $0.hsl.orange.l = 5
            $0.hsl.yellow.l = 0
            $0.hsl.blue.l = -55     // dramatic dark sky
            $0.hsl.aqua.l = -38
        }
    )

    public static let peterLikDramatic = Preset(
        id: "peter-lik",
        name: "Peter Lik",
        category: "Landscape",
        description: "Hyper-real saturated landscapes — punchy reds and blues, gallery print.",
        operations: build {
            $0.tone.contrast = 38
            $0.tone.highlights = -10
            $0.tone.shadows = 12
            $0.tone.whites = 12
            $0.tone.blacks = -22
            $0.color.saturation = 32
            $0.color.vibrance = 25
            $0.colorGrading.shadows.hue = 220
            $0.colorGrading.shadows.sat = 18
            $0.colorGrading.highlights.hue = 35
            $0.colorGrading.highlights.sat = 22
            $0.colorGrading.balance = 5
            $0.grain.amount = 4
            $0.hsl.red.s = 28
            $0.hsl.orange.s = 25
            $0.hsl.green.s = 28
            $0.hsl.blue.s = 35
            $0.hsl.aqua.s = 25
            $0.detail.sharpAmount = 50
        }
    )

    public static let mistyMorning = Preset(
        id: "misty-morning",
        name: "Misty Morning",
        category: "Landscape",
        description: "Soft fog atmosphere — low contrast, lifted blacks, cool muted tones.",
        operations: build {
            $0.tone.contrast = -25
            $0.tone.highlights = -22
            $0.tone.shadows = 38
            $0.tone.whites = -22
            $0.tone.blacks = 32
            $0.color.saturation = -32
            $0.color.vibrance = 8
            $0.colorGrading.shadows.hue = 200
            $0.colorGrading.shadows.sat = 15
            $0.colorGrading.highlights.hue = 195
            $0.colorGrading.highlights.sat = 8
            $0.colorGrading.balance = -8
            $0.grain.amount = 15
            $0.hsl.green.s = -22
            $0.hsl.blue.s = -10
        }
    )

    public static let goldenVista = Preset(
        id: "golden-vista",
        name: "Golden Vista",
        category: "Landscape",
        description: "Sunrise/sunset warmth — rich oranges, soft shadow lift, glowing sky.",
        operations: build {
            $0.tone.contrast = 18
            $0.tone.highlights = -22
            $0.tone.shadows = 18
            $0.tone.blacks = -12
            $0.color.saturation = 18
            $0.color.vibrance = 25
            $0.colorGrading.shadows.hue = 25
            $0.colorGrading.shadows.sat = 28
            $0.colorGrading.highlights.hue = 38
            $0.colorGrading.highlights.sat = 35
            $0.colorGrading.balance = 18
            $0.grain.amount = 8
            $0.hsl.red.s = 22
            $0.hsl.orange.s = 32
            $0.hsl.orange.l = 8
            $0.hsl.yellow.s = 25
            $0.hsl.yellow.l = 5
        }
    )

    public static let blueHour = Preset(
        id: "blue-hour",
        name: "Blue Hour",
        category: "Landscape",
        description: "Twilight after sunset — deep blue sky, warm city lights, cool atmosphere.",
        operations: build {
            $0.tone.contrast = 22
            $0.tone.highlights = -25
            $0.tone.shadows = 22
            $0.tone.blacks = -15
            $0.color.saturation = 12
            $0.color.vibrance = 22
            $0.colorGrading.shadows.hue = 220
            $0.colorGrading.shadows.sat = 35
            $0.colorGrading.highlights.hue = 30
            $0.colorGrading.highlights.sat = 22
            $0.colorGrading.balance = -15
            $0.grain.amount = 12
            $0.hsl.orange.s = 22  // warm windows
            $0.hsl.blue.s = 28
            $0.hsl.blue.l = -8
            $0.hsl.purple.s = 22
        }
    )

    public static let autumnVivid = Preset(
        id: "autumn-vivid",
        name: "Autumn Vivid",
        category: "Landscape",
        description: "Fall foliage — saturated reds, oranges, yellows; warm shadows.",
        operations: build {
            $0.tone.contrast = 25
            $0.tone.highlights = -12
            $0.tone.shadows = 5
            $0.tone.blacks = -15
            $0.color.saturation = 22
            $0.color.vibrance = 28
            $0.colorGrading.shadows.hue = 28
            $0.colorGrading.shadows.sat = 22
            $0.colorGrading.highlights.hue = 35
            $0.colorGrading.highlights.sat = 18
            $0.colorGrading.balance = 10
            $0.grain.amount = 8
            $0.hsl.red.s = 32
            $0.hsl.red.l = -3
            $0.hsl.orange.s = 35
            $0.hsl.orange.l = 5
            $0.hsl.yellow.s = 28
            $0.hsl.green.s = -8   // deemphasize remaining green
        }
    )

    public static let snowscape = Preset(
        id: "snowscape",
        name: "Snowscape",
        category: "Landscape",
        description: "Cold winter — bright clean snow, blue shadows, crisp air.",
        operations: build {
            $0.tone.contrast = 12
            $0.tone.highlights = -8
            $0.tone.shadows = 22
            $0.tone.whites = 22
            $0.tone.blacks = -15
            $0.color.saturation = -10
            $0.color.vibrance = 12
            $0.colorGrading.shadows.hue = 220
            $0.colorGrading.shadows.sat = 32
            $0.colorGrading.highlights.hue = 215
            $0.colorGrading.highlights.sat = 12
            $0.colorGrading.balance = -18
            $0.grain.amount = 5
            $0.hsl.blue.s = 22
            $0.hsl.aqua.s = 18
            $0.detail.sharpAmount = 45
        }
    )

    public static let tropicalParadise = Preset(
        id: "tropical-paradise",
        name: "Tropical Paradise",
        category: "Landscape",
        description: "Vivid beach — turquoise water, white sand, lush greens.",
        operations: build {
            $0.tone.contrast = 18
            $0.tone.highlights = -12
            $0.tone.shadows = 12
            $0.tone.whites = 8
            $0.tone.blacks = -10
            $0.color.saturation = 25
            $0.color.vibrance = 28
            $0.colorGrading.shadows.hue = 200
            $0.colorGrading.shadows.sat = 18
            $0.colorGrading.highlights.hue = 45
            $0.colorGrading.highlights.sat = 18
            $0.colorGrading.balance = 5
            $0.grain.amount = 5
            $0.hsl.green.s = 28
            $0.hsl.green.l = 5
            $0.hsl.aqua.s = 38
            $0.hsl.aqua.l = 8
            $0.hsl.blue.s = 30
        }
    )

    public static let desertRed = Preset(
        id: "desert-red",
        name: "Desert Red",
        category: "Landscape",
        description: "Red rock canyon — warm earth tones, deep amber, dust haze.",
        operations: build {
            $0.tone.contrast = 22
            $0.tone.highlights = -12
            $0.tone.shadows = 8
            $0.tone.blacks = -18
            $0.color.saturation = 18
            $0.color.vibrance = 22
            $0.colorGrading.shadows.hue = 18
            $0.colorGrading.shadows.sat = 32
            $0.colorGrading.highlights.hue = 28
            $0.colorGrading.highlights.sat = 38
            $0.colorGrading.balance = 22
            $0.grain.amount = 10
            $0.hsl.red.s = 28
            $0.hsl.red.l = -3
            $0.hsl.orange.s = 32
            $0.hsl.orange.l = 5
            $0.hsl.yellow.s = 18
            // Desaturate the sky and shift its hue toward warm/dusty so
            // the upper-sky region doesn't read as bright cyan against
            // the warm ground.
            $0.hsl.blue.h = -25
            $0.hsl.blue.s = -38
            $0.hsl.blue.l = -8
            $0.hsl.aqua.s = -25
        }
    )

    public static let forestEmerald = Preset(
        id: "forest-emerald",
        name: "Forest Emerald",
        category: "Landscape",
        description: "Lush green forest — rich foliage, mossy shadows, dappled light.",
        operations: build {
            $0.tone.contrast = 15
            $0.tone.highlights = -22
            $0.tone.shadows = 22
            $0.tone.blacks = -15
            $0.color.saturation = 12
            $0.color.vibrance = 25
            $0.colorGrading.shadows.hue = 130
            $0.colorGrading.shadows.sat = 22
            $0.colorGrading.highlights.hue = 60
            $0.colorGrading.highlights.sat = 18
            $0.colorGrading.balance = -5
            $0.grain.amount = 10
            $0.hsl.green.s = 32
            $0.hsl.green.l = 8
            $0.hsl.aqua.s = 18
            $0.hsl.yellow.s = 18
        }
    )

    public static let michaelKennaQuiet = Preset(
        id: "michael-kenna",
        name: "Michael Kenna",
        category: "Landscape",
        description: "Quiet long-exposure B&W — minimal, soft, zen-like.",
        operations: build {
            $0.color.saturation = -100
            $0.tone.contrast = -8
            $0.tone.highlights = -25
            $0.tone.shadows = 28
            $0.tone.whites = -18
            $0.tone.blacks = 12
            $0.grain.amount = 8
            $0.hsl.red.l = 5
            $0.hsl.blue.l = -8
        }
    )

    public static let nickBrandtAfrica = Preset(
        id: "nick-brandt",
        name: "Nick Brandt",
        category: "Landscape",
        description: "African savanna B&W — sculpted tonal range, dramatic skies.",
        operations: build {
            $0.color.saturation = -100
            $0.tone.contrast = 32
            $0.tone.highlights = -8
            $0.tone.shadows = -15
            $0.tone.whites = 12
            $0.tone.blacks = -32
            $0.grain.amount = 18
            $0.hsl.red.l = 12
            $0.hsl.orange.l = 8
            $0.hsl.yellow.l = 0
            $0.hsl.blue.l = -38
            $0.hsl.aqua.l = -28
        }
    )

    private static func build(_ mutate: (inout Operations) -> Void) -> Operations {
        var ops = Operations()
        mutate(&ops)
        return premiumTuned(ops)
    }

    private static func premiumTuned(_ source: Operations) -> Operations {
        var ops = source

        if ops.tone.highlightRecovery == 0 && (ops.tone.highlights < 0 || ops.tone.whites > 0) {
            let recovery = 10 + abs(ops.tone.highlights) / 3 + max(0, ops.tone.whites) / 4
            ops.tone.highlightRecovery = min(35, recovery)
        }

        if ops.toneCurve.rgb == ToneCurveOp.identity {
            ops.toneCurve.rgb = tunedToneCurve(for: ops)
        }

        if ops.color.saturation > 25 {
            ops.color.saturation = 25
            ops.color.vibrance = min(35, ops.color.vibrance + 8)
        }

        if ops.color.saturation > -95 {
            ops.hsl.orange.s = min(ops.hsl.orange.s, 14)
            ops.hsl.orange.l = max(ops.hsl.orange.l, 3)
            ops.hsl.red.s = min(ops.hsl.red.s, 24)
            ops.hsl.green.s = min(ops.hsl.green.s, 20)
            ops.hsl.aqua.s = min(ops.hsl.aqua.s, 26)
            ops.hsl.blue.s = min(ops.hsl.blue.s, 28)
        }

        if ops.grain.amount > 0 {
            if ops.grain.type == GrainOp.typeFine {
                ops.grain.type = grainType(for: ops)
            }
            ops.grain.size = max(12, min(ops.grain.size, ops.grain.amount >= 35 ? 34 : 26))
            ops.grain.roughness = max(38, min(ops.grain.roughness, ops.grain.amount >= 45 ? 72 : 58))
        }

        ops.detail.sharpAmount = min(ops.detail.sharpAmount, 55)
        ops.detail.sharpMasking = max(ops.detail.sharpMasking, ops.grain.amount > 20 ? 18 : 8)

        return ops
    }

    private static func tunedToneCurve(for ops: Operations) -> [[Double]] {
        let isBW = ops.color.saturation <= -95 || ops.bw.enabled
        let highContrast = ops.tone.contrast >= 28 || ops.tone.blacks <= -25
        let lifted = ops.tone.contrast < 0 || ops.tone.blacks > 0

        if isBW && highContrast {
            return [[0, 0.006], [0.18, 0.10], [0.52, 0.54], [0.84, 0.91], [1, 0.995]]
        } else if isBW {
            return [[0, 0.02], [0.24, 0.21], [0.55, 0.56], [0.86, 0.88], [1, 0.99]]
        } else if highContrast {
            return [[0, 0.012], [0.22, 0.17], [0.50, 0.51], [0.78, 0.84], [1, 0.985]]
        } else if lifted {
            return [[0, 0.04], [0.22, 0.21], [0.55, 0.56], [0.86, 0.88], [1, 0.985]]
        } else {
            return [[0, 0.012], [0.25, 0.23], [0.50, 0.505], [0.76, 0.80], [1, 0.99]]
        }
    }

    private static func grainType(for ops: Operations) -> String {
        if ops.grain.amount >= 65 { return GrainOp.typeHarsh }
        if ops.color.saturation <= -95 { return GrainOp.typeSilverRich }
        if ops.tone.contrast < 0 { return GrainOp.typeSoft }
        return GrainOp.typeCubic
    }
}

extension EditRecipe {
    /// Apply a preset by replacing every operation EXCEPT crop and lens
    /// correction / white balance (those are per-image and shouldn't be overwritten by a
    /// look you bought from someone else's preset).
    public mutating func apply(preset: Preset) {
        apply(preset: preset, amount: 1.0)
    }

    /// Apply a preset at parameter level. This is intentionally not
    /// pixel-blending: each operation is interpolated toward its neutral
    /// value, which keeps reduced-strength presets crisp and photographic.
    public mutating func apply(preset: Preset, amount: Double) {
        var ops = preset.operations.scaled(by: amount)
        ops.crop = operations.crop
        ops.lensCorrection = operations.lensCorrection
        ops.whiteBalance = operations.whiteBalance
        operations = ops
        modifiedAt = EditRecipe.now()
    }
}
