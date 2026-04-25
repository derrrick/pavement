import XCTest
@testable import PavementCore

final class ClampingTests: XCTestCase {
    func testClampUtility() {
        XCTAssertEqual(Clamping.clamp(5, to: 0...10), 5)
        XCTAssertEqual(Clamping.clamp(-3, to: 0...10), 0)
        XCTAssertEqual(Clamping.clamp(99, to: 0...10), 10)
        XCTAssertEqual(Clamping.clamp(0.5, to: 0.0...1.0), 0.5)
        XCTAssertEqual(Clamping.clamp(-0.1, to: 0.0...1.0), 0.0)
        XCTAssertEqual(Clamping.clamp(1.1, to: 0.0...1.0), 1.0)
    }

    func testInRangeRecipeIsUnchanged() {
        let original = EditRecipe()
        let clamped = Clamping.clamped(original)
        XCTAssertEqual(clamped, original)
    }

    func testExposureEVClampedToFiveStops() {
        var recipe = EditRecipe()
        recipe.operations.exposure.ev = 99.0
        let clamped = Clamping.clamped(recipe)
        XCTAssertEqual(clamped.operations.exposure.ev, 5.0)

        recipe.operations.exposure.ev = -99.0
        XCTAssertEqual(Clamping.clamped(recipe).operations.exposure.ev, -5.0)
    }

    func testToneFieldsClampedToHundred() {
        var recipe = EditRecipe()
        recipe.operations.tone.contrast = 9999
        recipe.operations.tone.shadows = -9999
        recipe.operations.tone.highlightRecovery = -10
        let clamped = Clamping.clamped(recipe)
        XCTAssertEqual(clamped.operations.tone.contrast, 100)
        XCTAssertEqual(clamped.operations.tone.shadows, -100)
        XCTAssertEqual(clamped.operations.tone.highlightRecovery, 0)
    }

    func testHSLBandsClamped() {
        var recipe = EditRecipe()
        recipe.operations.hsl.red.h = 999
        recipe.operations.hsl.blue.s = -500
        let clamped = Clamping.clamped(recipe)
        XCTAssertEqual(clamped.operations.hsl.red.h, 100)
        XCTAssertEqual(clamped.operations.hsl.blue.s, -100)
    }

    func testWhiteBalanceClampedToKelvinRange() {
        var recipe = EditRecipe()
        recipe.operations.whiteBalance.temp = 100_000
        recipe.operations.whiteBalance.tint = 999
        let clamped = Clamping.clamped(recipe)
        XCTAssertEqual(clamped.operations.whiteBalance.temp, 50_000)
        XCTAssertEqual(clamped.operations.whiteBalance.tint, 150)

        recipe.operations.whiteBalance.temp = 0
        XCTAssertEqual(Clamping.clamped(recipe).operations.whiteBalance.temp, 2000)
    }

    func testColorGradingHueClampedTo360() {
        var recipe = EditRecipe()
        recipe.operations.colorGrading.shadows.hue = 999
        recipe.operations.colorGrading.midtones.hue = -10
        let clamped = Clamping.clamped(recipe)
        XCTAssertEqual(clamped.operations.colorGrading.shadows.hue, 360)
        XCTAssertEqual(clamped.operations.colorGrading.midtones.hue, 0)
    }

    func testCropClampsNormalizedRect() {
        var recipe = EditRecipe()
        recipe.operations.crop.x = -0.5
        recipe.operations.crop.w = 99
        recipe.operations.crop.rotation = 88
        let clamped = Clamping.clamped(recipe)
        XCTAssertEqual(clamped.operations.crop.x, 0.0)
        XCTAssertEqual(clamped.operations.crop.w, 1.0)
        XCTAssertEqual(clamped.operations.crop.rotation, 45.0)
    }

    func testDetailRadiusClamped() {
        var recipe = EditRecipe()
        recipe.operations.detail.sharpRadius = 99.0
        recipe.operations.detail.sharpAmount = 9999
        let clamped = Clamping.clamped(recipe)
        XCTAssertEqual(clamped.operations.detail.sharpRadius, 3.0)
        XCTAssertEqual(clamped.operations.detail.sharpAmount, 150)

        recipe.operations.detail.sharpRadius = 0.0
        XCTAssertEqual(Clamping.clamped(recipe).operations.detail.sharpRadius, 0.5)
    }
}
