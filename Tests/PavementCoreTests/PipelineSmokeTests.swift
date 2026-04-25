import XCTest
import CoreImage
@testable import PavementCore

final class PipelineSmokeTests: XCTestCase {
    private func solidImage(color: CIColor, size: Int = 16) -> CIImage {
        CIImage(color: color).cropped(to: CGRect(x: 0, y: 0, width: size, height: size))
    }

    private func sample(_ image: CIImage) -> [Float] {
        let ctx = PipelineContext.shared.context
        var out = [UInt8](repeating: 0, count: 4)
        ctx.render(
            image,
            toBitmap: &out,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: ColorSpaces.sRGB
        )
        return out.map { Float($0) / 255.0 }
    }

    func testDefaultRecipeIsIdentity() {
        let recipe = EditRecipe()
        let input = solidImage(color: CIColor(red: 0.5, green: 0.5, blue: 0.5))
        let output = PipelineGraph().apply(recipe, to: input)

        let inSample = sample(input)
        let outSample = sample(output)
        for (i, o) in zip(inSample, outSample) {
            XCTAssertEqual(i, o, accuracy: 0.01,
                           "Default recipe must be byte-identical at every pixel")
        }
    }

    func testPositiveExposureBrightens() {
        var recipe = EditRecipe()
        recipe.operations.exposure.ev = 1.0
        let input = solidImage(color: CIColor(red: 0.25, green: 0.25, blue: 0.25))
        let output = PipelineGraph().apply(recipe, to: input)

        let outSample = sample(output)
        // +1 EV doubles linear-light intensity; 0.25 -> 0.5 in linear,
        // which is markedly brighter even after sRGB encoding.
        XCTAssertGreaterThan(outSample[0], 0.4)
    }

    func testNegativeExposureDarkens() {
        var recipe = EditRecipe()
        recipe.operations.exposure.ev = -2.0
        let input = solidImage(color: CIColor(red: 0.5, green: 0.5, blue: 0.5))
        let output = PipelineGraph().apply(recipe, to: input)

        let outSample = sample(output)
        XCTAssertLessThan(outSample[0], 0.4)
    }

    func testCustomWhiteBalanceShiftsImage() {
        var recipe = EditRecipe()
        recipe.operations.whiteBalance.mode = WhiteBalanceOp.custom
        recipe.operations.whiteBalance.temp = 3000 // very cool target -> warmer image
        let input = solidImage(color: CIColor(red: 0.5, green: 0.5, blue: 0.5))
        let output = PipelineGraph().apply(recipe, to: input)

        let outSample = sample(output)
        XCTAssertNotEqual(outSample[0], outSample[2], accuracy: 0.001,
                          "WB shift should make red and blue channels differ")
    }

    func testAsShotWhiteBalanceIsIdentity() {
        var recipe = EditRecipe()
        recipe.operations.whiteBalance.mode = WhiteBalanceOp.asShot
        recipe.operations.whiteBalance.temp = 3000
        let input = solidImage(color: CIColor(red: 0.5, green: 0.5, blue: 0.5))
        let output = PipelineGraph().apply(recipe, to: input)

        let inSample = sample(input)
        let outSample = sample(output)
        for (i, o) in zip(inSample, outSample) {
            XCTAssertEqual(i, o, accuracy: 0.01,
                           "asShot mode must not modify the image")
        }
    }
}
