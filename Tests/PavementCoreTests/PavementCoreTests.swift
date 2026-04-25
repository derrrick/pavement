import XCTest
@testable import PavementCore

final class PavementCoreTests: XCTestCase {
    func testVersionPresent() {
        XCTAssertFalse(PavementCore.version.isEmpty)
    }
}
