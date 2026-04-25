import XCTest
@testable import PavementCore
@testable import PavementUI

@MainActor
final class SelectionModelTests: XCTestCase {
    private func makeItems(_ count: Int) -> [SourceItem] {
        (0..<count).map { i in
            SourceItem(
                url: URL(fileURLWithPath: "/photos/IMG_\(i).RAF"),
                type: .raf,
                fileSize: 0
            )
        }
    }

    func testInitialState() {
        let model = SelectionModel()
        XCTAssertTrue(model.items.isEmpty)
        XCTAssertTrue(model.selection.isEmpty)
        XCTAssertNil(model.anchorIndex)
    }

    func testSetItemsSelectsFirst() {
        let model = SelectionModel()
        let items = makeItems(3)
        model.setItems(items)
        XCTAssertEqual(model.items, items)
        XCTAssertEqual(model.selection, [items[0].url])
        XCTAssertEqual(model.anchorIndex, 0)
    }

    func testPlainClickReplacesSelection() {
        let model = SelectionModel()
        let items = makeItems(5)
        model.setItems(items)
        model.handleClick(at: 3, shift: false, command: false)
        XCTAssertEqual(model.selection, [items[3].url])
        XCTAssertEqual(model.anchorIndex, 3)
    }

    func testShiftClickRangeSelects() {
        let model = SelectionModel()
        let items = makeItems(6)
        model.setItems(items)
        model.handleClick(at: 1, shift: false, command: false) // anchor at 1
        model.handleClick(at: 4, shift: true, command: false)

        let expected = Set(items[1...4].map { $0.url })
        XCTAssertEqual(model.selection, expected)
    }

    func testShiftClickBackwardsRangeSelects() {
        let model = SelectionModel()
        let items = makeItems(6)
        model.setItems(items)
        model.handleClick(at: 4, shift: false, command: false) // anchor at 4
        model.handleClick(at: 1, shift: true, command: false)

        let expected = Set(items[1...4].map { $0.url })
        XCTAssertEqual(model.selection, expected)
    }

    func testCommandClickTogglesIndividualItems() {
        let model = SelectionModel()
        let items = makeItems(5)
        model.setItems(items)
        model.handleClick(at: 0, shift: false, command: false) // {0}
        model.handleClick(at: 2, shift: false, command: true)  // {0, 2}
        model.handleClick(at: 4, shift: false, command: true)  // {0, 2, 4}
        XCTAssertEqual(model.selection, [items[0].url, items[2].url, items[4].url])

        model.handleClick(at: 2, shift: false, command: true)  // {0, 4}
        XCTAssertEqual(model.selection, [items[0].url, items[4].url])
    }

    func testMoveRightAndLeft() {
        let model = SelectionModel()
        let items = makeItems(4)
        model.setItems(items)
        model.move(.right)
        XCTAssertEqual(model.anchorIndex, 1)
        XCTAssertEqual(model.selection, [items[1].url])
        model.move(.right)
        model.move(.right)
        model.move(.right) // clamps at last index
        XCTAssertEqual(model.anchorIndex, 3)
        model.move(.left)
        XCTAssertEqual(model.anchorIndex, 2)
    }

    func testMoveUpDownUsesColumnCount() {
        let model = SelectionModel()
        let items = makeItems(12)
        model.setItems(items)
        model.columnCount = 4

        model.handleClick(at: 0, shift: false, command: false)
        model.move(.down)
        XCTAssertEqual(model.anchorIndex, 4)
        model.move(.down)
        XCTAssertEqual(model.anchorIndex, 8)
        model.move(.down) // clamps at last index
        XCTAssertEqual(model.anchorIndex, 11)
        model.move(.up)
        XCTAssertEqual(model.anchorIndex, 7)
    }

    func testSelectAll() {
        let model = SelectionModel()
        let items = makeItems(3)
        model.setItems(items)
        model.selectAll()
        XCTAssertEqual(model.selection.count, 3)
    }

    func testEmptyModelIgnoresMoves() {
        let model = SelectionModel()
        model.move(.right)
        model.move(.up)
        XCTAssertNil(model.anchorIndex)
    }
}
