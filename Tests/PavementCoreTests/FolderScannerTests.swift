import XCTest
@testable import PavementCore

final class FolderScannerTests: XCTestCase {
    private var rootURL: URL!

    override func setUpWithError() throws {
        let unique = "pavement-folder-scanner-\(UUID().uuidString)"
        rootURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(unique)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: rootURL)
    }

    private func touch(_ relativePath: String, bytes: Int = 0) throws -> URL {
        let url = rootURL.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = Data(repeating: 0, count: bytes)
        try data.write(to: url)
        return url
    }

    func testFindsRawAndIngestibleFiles() throws {
        _ = try touch("DSCF0001.RAF", bytes: 100)
        _ = try touch("nested/IMG_0002.CR3", bytes: 200)
        _ = try touch("nested/deeper/IMG_0003.dng", bytes: 50)
        _ = try touch("notes.txt")
        _ = try touch("preview.jpg", bytes: 30)

        let items = try FolderScanner().scan(folder: rootURL)
        let names = Set(items.map { $0.url.lastPathComponent })

        XCTAssertEqual(names, ["DSCF0001.RAF", "IMG_0002.CR3", "IMG_0003.dng", "preview.jpg"])
        let raf = items.first { $0.url.lastPathComponent == "DSCF0001.RAF" }
        XCTAssertEqual(raf?.type, .raf)
        XCTAssertEqual(raf?.fileSize, 100)
    }

    func testIgnoresHiddenAndManagedDirectories() throws {
        _ = try touch("DSCF0001.RAF")
        _ = try touch("_pavement/thumbnails/DSCF0001.jpg")
        _ = try touch("_pavement/ai_history.jsonl")
        _ = try touch("_exports/instagram/DSCF0001.jpg")
        _ = try touch(".hidden/secret.RAF")
        _ = try touch(".DS_Store")

        let items = try FolderScanner().scan(folder: rootURL)
        let paths = items.map { $0.url.lastPathComponent }
        XCTAssertEqual(paths, ["DSCF0001.RAF"])
    }

    func testReturnsEmptyForEmptyFolder() throws {
        let items = try FolderScanner().scan(folder: rootURL)
        XCTAssertTrue(items.isEmpty)
    }

    func testResultsAreSortedByPath() throws {
        _ = try touch("c.RAF")
        _ = try touch("a.RAF")
        _ = try touch("b.RAF")

        let items = try FolderScanner().scan(folder: rootURL)
        let names = items.map { $0.url.lastPathComponent }
        XCTAssertEqual(names, ["a.RAF", "b.RAF", "c.RAF"])
    }
}
