import XCTest
@testable import PavementCore

final class EditRecipeUnknownKeysTests: XCTestCase {
    private func loadFixture(_ name: String) throws -> Data {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
        return try Data(contentsOf: url)
    }

    func testUnknownKeysAreCapturedOnDecode() throws {
        let data = try loadFixture("recipe_v1_unknown_keys")
        let recipe = try EditRecipe.makeDecoder().decode(EditRecipe.self, from: data)

        XCTAssertEqual(recipe.unknownKeys.count, 3)
        XCTAssertEqual(recipe.unknownKeys["futureFlag"], .bool(true))
        XCTAssertEqual(recipe.unknownKeys["futureNumber"], .int(42))
        if case .object(let nested) = recipe.unknownKeys["futureSettings"] {
            XCTAssertEqual(nested["scopeStyle"], .string("luminance"))
            XCTAssertEqual(nested["tint"], .double(0.5))
        } else {
            XCTFail("futureSettings should decode as an object")
        }
    }

    func testUnknownKeysSurviveEncodeRoundTrip() throws {
        let data = try loadFixture("recipe_v1_unknown_keys")
        let decoder = EditRecipe.makeDecoder()
        let encoder = EditRecipe.makeEncoder()

        let recipe = try decoder.decode(EditRecipe.self, from: data)
        let reEncoded = try encoder.encode(recipe)
        let recipe2 = try decoder.decode(EditRecipe.self, from: reEncoded)

        XCTAssertEqual(recipe.unknownKeys, recipe2.unknownKeys)
        XCTAssertEqual(recipe, recipe2)
    }

    func testUnknownKeysAreVisibleInEncodedJSON() throws {
        let data = try loadFixture("recipe_v1_unknown_keys")
        let recipe = try EditRecipe.makeDecoder().decode(EditRecipe.self, from: data)
        let reEncoded = try EditRecipe.makeEncoder().encode(recipe)
        let json = try XCTUnwrap(String(data: reEncoded, encoding: .utf8))

        XCTAssertTrue(json.contains("\"futureFlag\""))
        XCTAssertTrue(json.contains("\"futureNumber\""))
        XCTAssertTrue(json.contains("\"futureSettings\""))
        XCTAssertTrue(json.contains("\"scopeStyle\""))
    }

    func testRecipeWithoutUnknownKeysHasEmptyDict() throws {
        let recipe = EditRecipe()
        XCTAssertTrue(recipe.unknownKeys.isEmpty)
    }
}
