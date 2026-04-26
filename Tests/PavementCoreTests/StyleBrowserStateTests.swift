import XCTest
@testable import PavementCore
@testable import PavementUI

@MainActor
final class StyleBrowserStateTests: XCTestCase {
    func testFavoritesPersist() throws {
        let defaults = try makeDefaults()
        let item = StyleBrowserItem.preset(BuiltinPresets.portraSkin)

        let first = StyleBrowserState(defaults: defaults)
        first.toggleFavorite(item)

        let second = StyleBrowserState(defaults: defaults)
        XCTAssertTrue(second.isFavorite(item))
    }

    func testRecentsUpdateAfterApplyAndPreserveOrder() throws {
        let defaults = try makeDefaults()
        let firstItem = StyleBrowserItem.preset(BuiltinPresets.portraSkin)
        let secondItem = StyleBrowserItem.preset(BuiltinPresets.triXPush)
        let state = StyleBrowserState(defaults: defaults)

        state.recordApply(firstItem)
        state.recordApply(secondItem)
        state.recordApply(firstItem)

        XCTAssertEqual(state.recentStyleIDs.prefix(2), [firstItem.id, secondItem.id])

        let reloaded = StyleBrowserState(defaults: defaults)
        XCTAssertEqual(reloaded.recentStyleIDs.prefix(2), [firstItem.id, secondItem.id])
    }

    func testCategoryFilteringIncludesBuiltInUserAndLUTStyles() throws {
        let defaults = try makeDefaults()
        let userStyle = Style(id: "user-a", name: "Studio User", category: "User", operations: Operations())
        let lutStyle = Style(id: "lut-a", name: "Soft Cube", category: "LUT", operations: Operations())
        let state = StyleBrowserState(defaults: defaults)

        state.selectedCategory = .builtIn
        XCTAssertTrue(state.filteredItems(builtIns: BuiltinPresets.all, styles: [userStyle, lutStyle]).contains(.preset(BuiltinPresets.portraSkin)))
        XCTAssertFalse(state.filteredItems(builtIns: BuiltinPresets.all, styles: [userStyle, lutStyle]).contains(.preset(BuiltinPresets.neutral)))

        state.selectedCategory = .user
        XCTAssertEqual(state.filteredItems(builtIns: BuiltinPresets.all, styles: [userStyle, lutStyle]), [.style(userStyle)])

        state.selectedCategory = .lut
        XCTAssertEqual(state.filteredItems(builtIns: BuiltinPresets.all, styles: [userStyle, lutStyle]), [.style(lutStyle)])
    }

    private func makeDefaults() throws -> UserDefaults {
        let suiteName = "pavement.styleBrowser.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
