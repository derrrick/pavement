import XCTest
@testable import PavementCore

final class PresetTests: XCTestCase {
    func testBuiltinsHaveStableIds() {
        let ids = BuiltinPresets.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "All preset IDs must be unique")
    }

    func testNeutralPresetIsIdentity() {
        var recipe = EditRecipe()
        recipe.operations.exposure.ev = 1.5
        recipe.apply(preset: BuiltinPresets.neutral)
        XCTAssertEqual(recipe.operations.exposure.ev, 0)
        XCTAssertEqual(recipe.operations.tone, ToneOp())
    }

    func testApplyingPresetPreservesCrop() {
        var recipe = EditRecipe()
        recipe.operations.crop.x = 0.1
        recipe.operations.crop.y = 0.2
        recipe.operations.crop.w = 0.5
        recipe.operations.crop.h = 0.5
        recipe.apply(preset: BuiltinPresets.tokyoNight)

        XCTAssertEqual(recipe.operations.crop.x, 0.1)
        XCTAssertEqual(recipe.operations.crop.y, 0.2)
        XCTAssertEqual(recipe.operations.crop.w, 0.5)
        XCTAssertEqual(recipe.operations.crop.h, 0.5)
    }

    func testApplyingPresetPreservesLensCorrection() {
        var recipe = EditRecipe()
        recipe.operations.lensCorrection.enabled = false
        recipe.apply(preset: BuiltinPresets.classicBW)
        XCTAssertFalse(recipe.operations.lensCorrection.enabled)
    }

    func testBWPresetsDesaturate() {
        for preset in [BuiltinPresets.classicBW, BuiltinPresets.highContrastBW, BuiltinPresets.softBW] {
            XCTAssertEqual(preset.operations.color.saturation, -100,
                           "\(preset.name) should fully desaturate")
        }
    }

    func testHighContrastBWHasStrongerCurveThanClassic() {
        XCTAssertGreaterThan(
            BuiltinPresets.highContrastBW.operations.tone.contrast,
            BuiltinPresets.classicBW.operations.tone.contrast
        )
    }

    func testTokyoNightHasGrainAndCoolShadows() {
        let preset = BuiltinPresets.tokyoNight
        XCTAssertGreaterThan(preset.operations.grain.amount, 0)
        XCTAssertGreaterThan(preset.operations.colorGrading.shadows.sat, 0)
        XCTAssertEqual(preset.operations.colorGrading.shadows.hue, 230)
    }

    func testApplyingPresetUpdatesModifiedAt() {
        var recipe = EditRecipe(createdAt: Date(timeIntervalSince1970: 0),
                                modifiedAt: Date(timeIntervalSince1970: 0))
        let initial = recipe.modifiedAt
        Thread.sleep(forTimeInterval: 1.1)  // EditRecipe.now() rounds to seconds
        recipe.apply(preset: BuiltinPresets.tokyoNight)
        XCTAssertGreaterThan(recipe.modifiedAt, initial)
    }
}
