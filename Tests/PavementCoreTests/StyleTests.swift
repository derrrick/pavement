import XCTest
@testable import PavementCore

final class StyleTests: XCTestCase {
    func testApplyStyleCopiesSpecifiedSections() {
        var style = Style(
            name: "Test",
            operations: makeOps {
                $0.exposure.ev = 0.5
                $0.tone.contrast = 25
                $0.color.saturation = 30
            },
            exclusions: Style.defaultExclusions  // crop / lens / WB excluded
        )
        style.exclusions.remove(.exposure)

        var recipe = EditRecipe()
        recipe.apply(style: style)
        XCTAssertEqual(recipe.operations.exposure.ev, 0.5)
        XCTAssertEqual(recipe.operations.tone.contrast, 25)
        XCTAssertEqual(recipe.operations.color.saturation, 30)
    }

    func testStyleExclusionsArePreserved() {
        var style = Style(
            name: "Test",
            operations: makeOps {
                $0.crop.x = 0.25
                $0.crop.w = 0.5
                $0.exposure.ev = 1.0
            }
        )
        // Defaults: crop is excluded
        XCTAssertTrue(style.exclusions.contains(.crop))

        var recipe = EditRecipe()
        recipe.operations.crop.x = 0.1
        recipe.operations.crop.w = 0.8
        recipe.apply(style: style)

        // Crop preserved, exposure replaced
        XCTAssertEqual(recipe.operations.crop.x, 0.1)
        XCTAssertEqual(recipe.operations.crop.w, 0.8)
        XCTAssertEqual(recipe.operations.exposure.ev, 1.0)

        // Now opt in to crop
        var styleWithCrop = style
        styleWithCrop.exclusions.remove(.crop)
        recipe.apply(style: styleWithCrop)
        XCTAssertEqual(recipe.operations.crop.x, 0.25)
        XCTAssertEqual(recipe.operations.crop.w, 0.5)
    }

    func testStyleLUTAttachesToRecipe() {
        let lut = LUTData(dimension: 16,
                          data: Data(repeating: 0, count: 16 * 16 * 16 * 4 * 4),
                          name: "Test LUT")
        let style = Style(name: "Test", operations: Operations(), lut: lut)
        var recipe = EditRecipe()
        recipe.apply(style: style)
        XCTAssertEqual(recipe.lut?.dimension, 16)
        XCTAssertEqual(recipe.lut?.name, "Test LUT")
    }

    func testStyleRecommendedOpacityScalesWhenApplied() {
        let style = Style(
            name: "Half",
            operations: makeOps {
                $0.exposure.ev = 1.0
                $0.tone.contrast = 40
                $0.colorGrading.highlights.hue = 48
                $0.colorGrading.highlights.sat = 20
            },
            recommendedOpacity: 0.5
        )

        var recipe = EditRecipe()
        recipe.apply(style: style)

        XCTAssertEqual(recipe.operations.exposure.ev, 0.5, accuracy: 0.001)
        XCTAssertEqual(recipe.operations.tone.contrast, 20)
        XCTAssertEqual(recipe.operations.colorGrading.highlights.hue, 48)
        XCTAssertEqual(recipe.operations.colorGrading.highlights.sat, 10)
    }

    func testStyleDecodeDefaultsRecommendedOpacity() throws {
        let json = """
        {
          "id": "legacy",
          "name": "Legacy",
          "category": "User",
          "description": "",
          "operations": {},
          "exclusions": ["crop", "lensCorrection", "whiteBalance"],
          "createdAt": "2026-04-26T12:00:00Z"
        }
        """
        let style = try EditRecipe.makeDecoder().decode(Style.self, from: Data(json.utf8))
        XCTAssertEqual(style.recommendedOpacity, 1.0)
    }

    private func makeOps(_ mutate: (inout Operations) -> Void) -> Operations {
        var ops = Operations()
        mutate(&ops)
        return ops
    }
}

final class CubeLUTTests: XCTestCase {
    func testParseSimpleCube() throws {
        // 2x2x2 cube — too small in production, but useful for tests.
        // Wait — we require dimension >= 8. Let me hand-build an 8³ cube.
        let dimension = 8
        var lines = ["LUT_3D_SIZE \(dimension)"]
        for b in 0..<dimension {
            for g in 0..<dimension {
                for r in 0..<dimension {
                    let R = Float(r) / Float(dimension - 1)
                    let G = Float(g) / Float(dimension - 1)
                    let B = Float(b) / Float(dimension - 1)
                    lines.append("\(R) \(G) \(B)")
                }
            }
        }
        let cubeText = lines.joined(separator: "\n")
        let lut = try CubeLUT.parse(cubeText, name: "Identity")
        XCTAssertEqual(lut.dimension, 8)
        XCTAssertEqual(lut.data.count, 8 * 8 * 8 * 4 * MemoryLayout<Float>.size)
    }

    func testParseFailsWithoutDimension() {
        XCTAssertThrowsError(try CubeLUT.parse("0 0 0\n1 1 1", name: "x"))
    }

    func testParseFailsWithIncompleteData() {
        let header = "LUT_3D_SIZE 8\n"
        XCTAssertThrowsError(try CubeLUT.parse(header + "0 0 0", name: "x"))
    }

    func testParseRespectsComments() throws {
        var lines = ["# my LUT", "LUT_3D_SIZE 8"]
        for _ in 0..<(8 * 8 * 8) { lines.append("0.5 0.5 0.5  # mid gray") }
        let lut = try CubeLUT.parse(lines.joined(separator: "\n"), name: "Mid")
        XCTAssertEqual(lut.dimension, 8)
    }
}

final class LightroomXMPTests: XCTestCase {
    func testParseBasicAdjustments() throws {
        let xmp = """
        <?xml version="1.0" encoding="UTF-8"?>
        <x:xmpmeta xmlns:x="adobe:ns:meta/">
          <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
            <rdf:Description xmlns:crs="http://ns.adobe.com/camera-raw-settings/1.0/"
              crs:Exposure2012="+0.50"
              crs:Contrast2012="+25"
              crs:Highlights2012="-30"
              crs:Shadows2012="+20"
              crs:Whites2012="+10"
              crs:Blacks2012="-15"
              crs:Vibrance="+15"
              crs:Saturation="-10"
              crs:Temperature="5500"
              crs:Tint="+5">
            </rdf:Description>
          </rdf:RDF>
        </x:xmpmeta>
        """
        let style = try LightroomXMP.parse(xmp, name: "Test Preset")
        XCTAssertEqual(style.name, "Test Preset")
        XCTAssertEqual(style.category, "Lightroom")
        XCTAssertEqual(style.operations.exposure.ev, 0.5, accuracy: 0.001)
        XCTAssertEqual(style.operations.tone.contrast, 25)
        XCTAssertEqual(style.operations.tone.highlights, -30)
        XCTAssertEqual(style.operations.tone.shadows, 20)
        XCTAssertEqual(style.operations.tone.whites, 10)
        XCTAssertEqual(style.operations.tone.blacks, -15)
        XCTAssertEqual(style.operations.color.vibrance, 15)
        XCTAssertEqual(style.operations.color.saturation, -10)
        XCTAssertEqual(style.operations.whiteBalance.mode, WhiteBalanceOp.custom)
        XCTAssertEqual(style.operations.whiteBalance.temp, 5500)
        XCTAssertEqual(style.operations.whiteBalance.tint, 5)
    }

    func testParseHSLBands() throws {
        let xmp = """
        <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
          <rdf:Description xmlns:crs="..."
            crs:HueAdjustmentBlue="-30"
            crs:SaturationAdjustmentBlue="+50"
            crs:LuminanceAdjustmentBlue="-20"
            crs:HueAdjustmentRed="+10">
          </rdf:Description>
        </rdf:RDF>
        """
        let style = try LightroomXMP.parse(xmp, name: "HSL Test")
        XCTAssertEqual(style.operations.hsl.blue.h, -30)
        XCTAssertEqual(style.operations.hsl.blue.s, 50)
        XCTAssertEqual(style.operations.hsl.blue.l, -20)
        XCTAssertEqual(style.operations.hsl.red.h, 10)
    }

    func testParseSplitToning() throws {
        let xmp = """
        <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
          <rdf:Description xmlns:crs="..."
            crs:SplitToningShadowHue="220"
            crs:SplitToningShadowSaturation="40"
            crs:SplitToningHighlightHue="30"
            crs:SplitToningHighlightSaturation="25">
          </rdf:Description>
        </rdf:RDF>
        """
        let style = try LightroomXMP.parse(xmp, name: "ST Test")
        XCTAssertEqual(style.operations.colorGrading.shadows.hue, 220)
        XCTAssertEqual(style.operations.colorGrading.shadows.sat, 40)
        XCTAssertEqual(style.operations.colorGrading.highlights.hue, 30)
        XCTAssertEqual(style.operations.colorGrading.highlights.sat, 25)
    }

    func testEmptyXMPThrows() {
        let xmp = "<rdf:RDF xmlns:rdf=\"x\"><rdf:Description/></rdf:RDF>"
        XCTAssertThrowsError(try LightroomXMP.parse(xmp, name: "Empty"))
    }
}
