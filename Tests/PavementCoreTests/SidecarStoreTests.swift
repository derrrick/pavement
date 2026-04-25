import XCTest
@testable import PavementCore

final class SidecarStoreTests: XCTestCase {
    private var tmpDir: URL!

    override func setUpWithError() throws {
        let unique = "pavement-sidecar-\(UUID().uuidString)"
        tmpDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(unique)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tmpDir)
    }

    private func dummySource(named: String) throws -> URL {
        let url = tmpDir.appendingPathComponent(named)
        try Data("raw".utf8).write(to: url)
        return url
    }

    func testSidecarURLAppendsExtension() {
        let source = URL(fileURLWithPath: "/photos/DSCF1234.RAF")
        let sidecar = SidecarStore.sidecarURL(for: source)
        XCTAssertEqual(sidecar.lastPathComponent, "DSCF1234.RAF.pavement.json")
    }

    func testLoadReturnsNilWhenAbsent() throws {
        let source = try dummySource(named: "DSCF1.RAF")
        let store = SidecarStore()
        XCTAssertNil(try store.load(for: source))
    }

    func testSaveAndLoadRoundTrip() throws {
        let source = try dummySource(named: "DSCF2.RAF")
        let store = SidecarStore()

        var recipe = EditRecipe()
        recipe.source.path = source.lastPathComponent
        recipe.source.fingerprint = "sha256:test"
        recipe.operations.exposure.ev = 0.7
        recipe.operations.tone.contrast = 22
        recipe.ai.lastPrompt = "warm chiaroscuro"

        try store.save(recipe, for: source)
        let loaded = try XCTUnwrap(try store.load(for: source))

        XCTAssertEqual(loaded, recipe)
        XCTAssertTrue(FileManager.default.fileExists(atPath: SidecarStore.sidecarURL(for: source).path))
    }

    func testSaveOverwritesPreviousSidecar() throws {
        let source = try dummySource(named: "DSCF3.RAF")
        let store = SidecarStore()

        var first = EditRecipe()
        first.source.path = "first"
        try store.save(first, for: source)

        var second = EditRecipe()
        second.source.path = "second"
        try store.save(second, for: source)

        let loaded = try XCTUnwrap(try store.load(for: source))
        XCTAssertEqual(loaded.source.path, "second")
    }

    func testSaveDoesNotLeaveTempFile() throws {
        let source = try dummySource(named: "DSCF4.RAF")
        let store = SidecarStore()
        try store.save(EditRecipe(), for: source)

        let target = SidecarStore.sidecarURL(for: source)
        let tmp = target.deletingLastPathComponent()
            .appendingPathComponent(target.lastPathComponent + ".tmp")
        XCTAssertFalse(FileManager.default.fileExists(atPath: tmp.path),
                       "Atomic save must not leave the .tmp file behind")
    }
}
