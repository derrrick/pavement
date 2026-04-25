import XCTest
@testable import PavementCore

final class EditRecipeCodableTests: XCTestCase {
    private func loadFixture(_ name: String) throws -> Data {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
        return try Data(contentsOf: url)
    }

    func testFullRecipeRoundTrip() throws {
        let original = try loadFixture("recipe_v1_full")
        let decoder = EditRecipe.makeDecoder()
        let encoder = EditRecipe.makeEncoder()

        let recipe = try decoder.decode(EditRecipe.self, from: original)
        let reEncoded = try encoder.encode(recipe)
        let recipe2 = try decoder.decode(EditRecipe.self, from: reEncoded)

        XCTAssertEqual(recipe, recipe2, "Round-trip should preserve all fields exactly")
    }

    func testFullRecipePopulatedFieldsMatch() throws {
        let data = try loadFixture("recipe_v1_full")
        let recipe = try EditRecipe.makeDecoder().decode(EditRecipe.self, from: data)

        XCTAssertEqual(recipe.schemaVersion, 1)
        XCTAssertEqual(recipe.source.camera, "Fujifilm X-E4")
        XCTAssertEqual(recipe.source.iso, 800)
        XCTAssertEqual(recipe.source.fingerprint, "sha256:abcd1234")
        XCTAssertEqual(recipe.operations.crop.aspect, "4:5")
        XCTAssertEqual(recipe.operations.crop.rotation, 1.5)
        XCTAssertEqual(recipe.operations.exposure.ev, 0.3)
        XCTAssertEqual(recipe.operations.tone.contrast, 30)
        XCTAssertEqual(recipe.operations.tone.shadows, 35)
        XCTAssertEqual(recipe.operations.tone.highlightRecovery, 50)
        XCTAssertEqual(recipe.operations.toneCurve.rgb.count, 5)
        XCTAssertEqual(recipe.operations.hsl.orange.h, 5)
        XCTAssertEqual(recipe.operations.hsl.blue.s, -20)
        XCTAssertEqual(recipe.operations.colorGrading.shadows.hue, 220)
        XCTAssertEqual(recipe.operations.colorGrading.balance, 10)
        XCTAssertEqual(recipe.operations.detail.sharpAmount, 40)
        XCTAssertEqual(recipe.operations.grain.amount, 15)
        XCTAssertEqual(recipe.operations.vignette.amount, -25)
        XCTAssertFalse(recipe.operations.bw.enabled)
        XCTAssertEqual(recipe.ai.lastModel, "claude-sonnet-4-6")
        XCTAssertEqual(recipe.ai.lastReferenceFingerprints?.count, 2)
    }

    func testMinimalRecipeMatchesPlanDefaults() throws {
        let data = try loadFixture("recipe_v1_minimal")
        let recipe = try EditRecipe.makeDecoder().decode(EditRecipe.self, from: data)

        XCTAssertEqual(recipe.schemaVersion, 1)
        XCTAssertEqual(recipe.operations.crop, CropOp())
        XCTAssertEqual(recipe.operations.lensCorrection, LensCorrectionOp())
        XCTAssertEqual(recipe.operations.whiteBalance, WhiteBalanceOp())
        XCTAssertEqual(recipe.operations.exposure, ExposureOp())
        XCTAssertEqual(recipe.operations.tone, ToneOp())
        XCTAssertEqual(recipe.operations.toneCurve, ToneCurveOp())
        XCTAssertEqual(recipe.operations.hsl, HSLOp())
        XCTAssertEqual(recipe.operations.colorGrading, ColorGradingOp())
        XCTAssertEqual(recipe.operations.bw, BWOp())
        XCTAssertEqual(recipe.operations.detail, DetailOp())
        XCTAssertEqual(recipe.operations.grain, GrainOp())
        XCTAssertEqual(recipe.operations.vignette, VignetteOp())
        XCTAssertEqual(recipe.ai, AIMetadata())
    }

    func testDefaultRecipeEncodesSchemaVersion() throws {
        let recipe = EditRecipe()
        let data = try EditRecipe.makeEncoder().encode(recipe)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertTrue(json.contains("\"schemaVersion\" : 1"), "schemaVersion must always be encoded")
    }

    func testInitDefaultsMatchPlan() {
        let recipe = EditRecipe()

        XCTAssertEqual(recipe.schemaVersion, EditRecipe.currentSchemaVersion)

        XCTAssertEqual(recipe.operations.crop.x, 0.0)
        XCTAssertEqual(recipe.operations.crop.y, 0.0)
        XCTAssertEqual(recipe.operations.crop.w, 1.0)
        XCTAssertEqual(recipe.operations.crop.h, 1.0)
        XCTAssertEqual(recipe.operations.crop.aspect, "free")
        XCTAssertTrue(recipe.operations.crop.enabled)

        XCTAssertEqual(recipe.operations.whiteBalance.temp, 5500)
        XCTAssertEqual(recipe.operations.whiteBalance.tint, 0)

        XCTAssertEqual(recipe.operations.detail.sharpAmount, 30)
        XCTAssertEqual(recipe.operations.detail.sharpRadius, 1.0)
        XCTAssertEqual(recipe.operations.detail.noiseColor, 25)

        XCTAssertEqual(recipe.operations.grain.size, 25)
        XCTAssertEqual(recipe.operations.grain.roughness, 50)

        XCTAssertEqual(recipe.operations.vignette.midpoint, 50)
        XCTAssertEqual(recipe.operations.vignette.feather, 50)

        XCTAssertEqual(recipe.operations.colorGrading.blending, 50)

        XCTAssertEqual(recipe.operations.toneCurve.rgb, ToneCurveOp.identity)
    }

    func testEncodeDecodeRoundTrip() throws {
        var recipe = EditRecipe()
        recipe.source.path = "DSCF9999.RAF"
        recipe.source.fingerprint = "sha256:test"
        recipe.source.iso = 1600
        recipe.operations.exposure.ev = -0.5
        recipe.operations.tone.contrast = 25
        recipe.operations.hsl.red.h = 10
        recipe.ai.lastPrompt = "test prompt"

        let encoder = EditRecipe.makeEncoder()
        let decoder = EditRecipe.makeDecoder()
        let data = try encoder.encode(recipe)
        let decoded = try decoder.decode(EditRecipe.self, from: data)

        XCTAssertEqual(decoded, recipe)
    }
}
