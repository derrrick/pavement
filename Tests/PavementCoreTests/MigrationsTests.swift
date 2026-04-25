import XCTest
@testable import PavementCore

final class MigrationsTests: XCTestCase {
    func testIdentityForCurrentVersion() throws {
        var recipe = EditRecipe()
        recipe.schemaVersion = EditRecipe.currentSchemaVersion
        let before = recipe
        try Migrations.upgrade(&recipe)
        XCTAssertEqual(recipe, before)
        XCTAssertEqual(recipe.schemaVersion, EditRecipe.currentSchemaVersion)
    }

    func testRejectsUnknownVersion() {
        var recipe = EditRecipe()
        recipe.schemaVersion = EditRecipe.currentSchemaVersion + 1
        XCTAssertThrowsError(try Migrations.upgrade(&recipe)) { error in
            guard case MigrationError.unsupportedVersion(let v) = error else {
                XCTFail("Expected unsupportedVersion error, got \(error)")
                return
            }
            XCTAssertEqual(v, EditRecipe.currentSchemaVersion + 1)
        }
    }

    func testRejectsZeroVersion() {
        var recipe = EditRecipe()
        recipe.schemaVersion = 0
        XCTAssertThrowsError(try Migrations.upgrade(&recipe))
    }

    func testRejectsNegativeVersion() {
        var recipe = EditRecipe()
        recipe.schemaVersion = -3
        XCTAssertThrowsError(try Migrations.upgrade(&recipe))
    }
}
