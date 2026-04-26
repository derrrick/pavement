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
        recipe.apply(preset: BuiltinPresets.tokyoNeonNoir)

        XCTAssertEqual(recipe.operations.crop.x, 0.1)
        XCTAssertEqual(recipe.operations.crop.y, 0.2)
        XCTAssertEqual(recipe.operations.crop.w, 0.5)
        XCTAssertEqual(recipe.operations.crop.h, 0.5)
    }

    func testApplyingPresetPreservesLensCorrection() {
        var recipe = EditRecipe()
        recipe.operations.lensCorrection.enabled = false
        recipe.apply(preset: BuiltinPresets.parisHenriSilver)
        XCTAssertFalse(recipe.operations.lensCorrection.enabled)
    }

    func testApplyingPresetPreservesWhiteBalance() {
        var recipe = EditRecipe()
        recipe.operations.whiteBalance.mode = WhiteBalanceOp.custom
        recipe.operations.whiteBalance.temp = 4300
        recipe.operations.whiteBalance.tint = -12
        recipe.apply(preset: BuiltinPresets.portraSkin)

        XCTAssertEqual(recipe.operations.whiteBalance.mode, WhiteBalanceOp.custom)
        XCTAssertEqual(recipe.operations.whiteBalance.temp, 4300)
        XCTAssertEqual(recipe.operations.whiteBalance.tint, -12)
    }

    func testPresetAmountScalesParametersNotPixels() {
        var recipe = EditRecipe()
        recipe.apply(preset: BuiltinPresets.tokyoNeonNoir, amount: 0.5)

        XCTAssertEqual(recipe.operations.tone.contrast, BuiltinPresets.tokyoNeonNoir.operations.tone.contrast / 2)
        XCTAssertEqual(recipe.operations.colorGrading.shadows.hue, BuiltinPresets.tokyoNeonNoir.operations.colorGrading.shadows.hue)
        XCTAssertEqual(recipe.operations.colorGrading.shadows.sat, BuiltinPresets.tokyoNeonNoir.operations.colorGrading.shadows.sat / 2)
        XCTAssertLessThan(recipe.operations.grain.amount, BuiltinPresets.tokyoNeonNoir.operations.grain.amount)
        XCTAssertNotEqual(recipe.operations.toneCurve.rgb, BuiltinPresets.tokyoNeonNoir.operations.toneCurve.rgb)
    }

    func testBWPresetsDesaturate() {
        for preset in [BuiltinPresets.triXPush, BuiltinPresets.moriyama, BuiltinPresets.parisHenriSilver] {
            XCTAssertEqual(preset.operations.color.saturation, -100,
                           "\(preset.name) should fully desaturate")
        }
    }

    func testMoriyamaHasStrongerContrastThanVivianMaier() {
        XCTAssertGreaterThan(
            BuiltinPresets.moriyama.operations.tone.contrast,
            BuiltinPresets.vivianMaier.operations.tone.contrast
        )
    }

    func testTokyoNeonNoirHasGrainAndCoolShadows() {
        let preset = BuiltinPresets.tokyoNeonNoir
        XCTAssertGreaterThan(preset.operations.grain.amount, 0)
        XCTAssertGreaterThan(preset.operations.colorGrading.shadows.sat, 0)
        XCTAssertEqual(preset.operations.colorGrading.shadows.hue, 195)
    }

    func testApplyingPresetUpdatesModifiedAt() {
        var recipe = EditRecipe(createdAt: Date(timeIntervalSince1970: 0),
                                modifiedAt: Date(timeIntervalSince1970: 0))
        let initial = recipe.modifiedAt
        Thread.sleep(forTimeInterval: 1.1)  // EditRecipe.now() rounds to seconds
        recipe.apply(preset: BuiltinPresets.tokyoNeonNoir)
        XCTAssertGreaterThan(recipe.modifiedAt, initial)
    }

    func testEachCategoryHasPresets() {
        let categories = Set(BuiltinPresets.all.map(\.category))
        XCTAssertTrue(categories.contains("B&W"))
        XCTAssertTrue(categories.contains("Film"))
        XCTAssertTrue(categories.contains("Street"))
    }
}
