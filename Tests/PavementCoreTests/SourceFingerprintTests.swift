import XCTest
@testable import PavementCore

final class SourceFingerprintTests: XCTestCase {
    private var tmpDir: URL!

    override func setUpWithError() throws {
        let unique = "pavement-fingerprint-\(UUID().uuidString)"
        tmpDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(unique)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tmpDir)
    }

    private func writeFile(named: String, bytes: Data) throws -> URL {
        let url = tmpDir.appendingPathComponent(named)
        try bytes.write(to: url)
        return url
    }

    func testSmallFileHashesEntireContents() throws {
        let url = try writeFile(named: "small.bin", bytes: Data("hello".utf8))
        let fp = try SourceFingerprint.compute(url: url)
        // sha256("hello") = 2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824
        XCTAssertEqual(fp, "sha256:2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824")
    }

    func testEmptyFileHashesEmptyData() throws {
        let url = try writeFile(named: "empty.bin", bytes: Data())
        let fp = try SourceFingerprint.compute(url: url)
        // sha256("") = e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
        XCTAssertEqual(fp, "sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
    }

    func testLargeFileHashesHeadAndTail() throws {
        let chunkSize = SourceFingerprint.chunkSize
        var data = Data()
        data.append(Data(repeating: 0xAA, count: chunkSize))
        data.append(Data(repeating: 0x00, count: chunkSize)) // middle gets ignored
        data.append(Data(repeating: 0xBB, count: chunkSize))
        let url = try writeFile(named: "big.bin", bytes: data)

        let fp = try SourceFingerprint.compute(url: url)
        XCTAssertTrue(fp.hasPrefix("sha256:"))
        XCTAssertEqual(fp.count, "sha256:".count + 64)

        // Mutating the middle of a large file MUST NOT change the fingerprint.
        var mutated = data
        let middleIndex = chunkSize + (chunkSize / 2)
        mutated[middleIndex] = 0xFF
        let mutatedURL = try writeFile(named: "big-mutated.bin", bytes: mutated)
        let fp2 = try SourceFingerprint.compute(url: mutatedURL)
        XCTAssertEqual(fp, fp2, "Middle byte changes should not affect head+tail fingerprint")

        // Mutating the head MUST change the fingerprint.
        var headMutated = data
        headMutated[0] = 0xFF
        let headURL = try writeFile(named: "big-head.bin", bytes: headMutated)
        let fp3 = try SourceFingerprint.compute(url: headURL)
        XCTAssertNotEqual(fp, fp3)
    }

    func testHashIsStableAcrossRuns() throws {
        let url = try writeFile(named: "repeat.bin", bytes: Data(repeating: 0x42, count: 10_000))
        let fp1 = try SourceFingerprint.compute(url: url)
        let fp2 = try SourceFingerprint.compute(url: url)
        XCTAssertEqual(fp1, fp2)
    }
}
