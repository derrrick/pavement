import Foundation

public struct Preset: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let category: String
    public let operations: Operations

    public init(id: String, name: String, category: String, operations: Operations) {
        self.id = id
        self.name = name
        self.category = category
        self.operations = operations
    }
}

/// Built-in presets curated for street photography. Applied by replacing
/// every operations field except crop / lensCorrection / source — those
/// stay per-image. Users can swap presets without losing their crop.
public enum BuiltinPresets {
    public static let all: [Preset] = [
        neutral,
        classicBW, highContrastBW, softBW,
        fadedFilm, cinematicTealOrange,
        punchyColor, sunBleached, tokyoNight, moodyStreet
    ]

    public static let neutral = Preset(
        id: "neutral",
        name: "Neutral",
        category: "Reset",
        operations: Operations()
    )

    public static let classicBW = Preset(
        id: "classic-bw",
        name: "Classic B&W",
        category: "B&W",
        operations: build {
            $0.color.saturation = -100
            $0.tone.contrast = 12
            $0.tone.blacks = -8
            $0.tone.whites = 8
        }
    )

    public static let highContrastBW = Preset(
        id: "high-contrast-bw",
        name: "High Contrast B&W",
        category: "B&W",
        operations: build {
            $0.color.saturation = -100
            $0.tone.contrast = 45
            $0.tone.blacks = -28
            $0.tone.whites = 18
            $0.tone.shadows = -12
            $0.tone.highlights = -10
            $0.detail.sharpAmount = 50
        }
    )

    public static let softBW = Preset(
        id: "soft-bw",
        name: "Soft B&W",
        category: "B&W",
        operations: build {
            $0.color.saturation = -100
            $0.tone.contrast = -8
            $0.tone.shadows = 20
            $0.tone.blacks = 25
            $0.grain.amount = 18
        }
    )

    public static let fadedFilm = Preset(
        id: "faded-film",
        name: "Faded Film",
        category: "Film",
        operations: build {
            $0.tone.contrast = -15
            $0.tone.shadows = 25
            $0.tone.blacks = 35
            $0.color.saturation = -12
            $0.color.luminance = 5
            $0.colorGrading.shadows.hue = 30
            $0.colorGrading.shadows.sat = 12
            $0.grain.amount = 15
        }
    )

    public static let cinematicTealOrange = Preset(
        id: "cinematic-teal-orange",
        name: "Cinematic",
        category: "Cinematic",
        operations: build {
            $0.tone.contrast = 25
            $0.tone.highlights = -15
            $0.tone.shadows = 18
            $0.colorGrading.shadows.hue = 195
            $0.colorGrading.shadows.sat = 25
            $0.colorGrading.highlights.hue = 30
            $0.colorGrading.highlights.sat = 22
            $0.colorGrading.balance = 12
        }
    )

    public static let punchyColor = Preset(
        id: "punchy-color",
        name: "Punchy",
        category: "Color",
        operations: build {
            $0.tone.contrast = 30
            $0.tone.whites = 10
            $0.tone.blacks = -10
            $0.color.vibrance = 30
            $0.color.saturation = 8
        }
    )

    public static let sunBleached = Preset(
        id: "sun-bleached",
        name: "Sun-bleached",
        category: "Street",
        operations: build {
            $0.tone.contrast = 10
            $0.tone.highlights = -25
            $0.tone.shadows = 32
            $0.tone.blacks = 22
            $0.color.saturation = -15
            $0.colorGrading.highlights.hue = 40
            $0.colorGrading.highlights.sat = 18
            $0.colorGrading.shadows.hue = 50
            $0.colorGrading.shadows.sat = 10
        }
    )

    public static let tokyoNight = Preset(
        id: "tokyo-night",
        name: "Tokyo Night",
        category: "Street",
        operations: build {
            $0.tone.contrast = 22
            $0.tone.shadows = 26
            $0.tone.blacks = -18
            $0.tone.highlights = -20
            $0.color.saturation = 12
            $0.color.vibrance = 22
            $0.colorGrading.shadows.hue = 230
            $0.colorGrading.shadows.sat = 22
            $0.colorGrading.highlights.hue = 5
            $0.colorGrading.highlights.sat = 12
            $0.grain.amount = 12
        }
    )

    public static let moodyStreet = Preset(
        id: "moody-street",
        name: "Moody Street",
        category: "Street",
        operations: build {
            $0.tone.contrast = -8
            $0.tone.shadows = -22
            $0.tone.highlights = -18
            $0.color.saturation = -22
            $0.color.luminance = -8
            $0.colorGrading.shadows.hue = 220
            $0.colorGrading.shadows.sat = 18
            $0.grain.amount = 14
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
