import XCTest
import CoreImage
@testable import PavementCore

final class CachedDecodeTests: XCTestCase {
    func testFirstAccessInvokesProvider() throws {
        var calls = 0
        let cache = CachedDecode { _ in
            calls += 1
            return CIImage(color: .red).cropped(to: CGRect(x: 0, y: 0, width: 4, height: 4))
        }
        _ = try cache.image(for: URL(fileURLWithPath: "/x/A.RAF"))
        XCTAssertEqual(calls, 1)
    }

    func testSubsequentAccessReusesCachedImage() throws {
        var calls = 0
        let cache = CachedDecode { _ in
            calls += 1
            return CIImage(color: .red).cropped(to: CGRect(x: 0, y: 0, width: 4, height: 4))
        }
        let url = URL(fileURLWithPath: "/x/A.RAF")
        _ = try cache.image(for: url)
        _ = try cache.image(for: url)
        _ = try cache.image(for: url)
        XCTAssertEqual(calls, 1, "Provider must run exactly once per URL")
    }

    func testDifferentURLsAreCachedSeparately() throws {
        var calls = 0
        let cache = CachedDecode { _ in
            calls += 1
            return CIImage(color: .red).cropped(to: CGRect(x: 0, y: 0, width: 4, height: 4))
        }
        _ = try cache.image(for: URL(fileURLWithPath: "/x/A.RAF"))
        _ = try cache.image(for: URL(fileURLWithPath: "/x/B.RAF"))
        _ = try cache.image(for: URL(fileURLWithPath: "/x/A.RAF"))
        _ = try cache.image(for: URL(fileURLWithPath: "/x/B.RAF"))
        XCTAssertEqual(calls, 2)
        XCTAssertEqual(cache.count, 2)
    }

    func testInvalidateForcesReDecode() throws {
        var calls = 0
        let cache = CachedDecode { _ in
            calls += 1
            return CIImage(color: .red).cropped(to: CGRect(x: 0, y: 0, width: 4, height: 4))
        }
        let url = URL(fileURLWithPath: "/x/A.RAF")
        _ = try cache.image(for: url)
        cache.invalidate(url)
        _ = try cache.image(for: url)
        XCTAssertEqual(calls, 2)
    }

    func testClearEvictsAllEntries() throws {
        var calls = 0
        let cache = CachedDecode { _ in
            calls += 1
            return CIImage(color: .red).cropped(to: CGRect(x: 0, y: 0, width: 4, height: 4))
        }
        _ = try cache.image(for: URL(fileURLWithPath: "/x/A.RAF"))
        _ = try cache.image(for: URL(fileURLWithPath: "/x/B.RAF"))
        XCTAssertEqual(cache.count, 2)
        cache.clear()
        XCTAssertEqual(cache.count, 0)
        _ = try cache.image(for: URL(fileURLWithPath: "/x/A.RAF"))
        XCTAssertEqual(calls, 3)
    }

    func testCachedReturnsNilWhenAbsent() {
        let cache = CachedDecode()
        XCTAssertNil(cache.cached(for: URL(fileURLWithPath: "/never/touched.RAF")))
    }

    func testProviderErrorPropagates() {
        struct Fail: Error {}
        let cache = CachedDecode { _ in throw Fail() }
        XCTAssertThrowsError(try cache.image(for: URL(fileURLWithPath: "/x/A.RAF")))
    }
}
