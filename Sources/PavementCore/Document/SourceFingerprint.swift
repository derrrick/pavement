import Foundation
import CryptoKit

public enum SourceFingerprint {
    /// Hash the first `chunkSize` and last `chunkSize` bytes of the file.
    /// For files smaller than 2 * chunkSize, hash the entire file.
    /// This is fast even on 60MB CR3s and stable enough that legitimate edits
    /// (like renaming) produce the same fingerprint.
    public static let chunkSize: Int = 1024 * 1024 // 1MB

    /// Returns "sha256:<64hex>".
    public static func compute(url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        let size = try handle.seekToEnd()
        try handle.seek(toOffset: 0)

        var hasher = SHA256()

        if size <= UInt64(chunkSize * 2) {
            let data = try handle.readToEnd() ?? Data()
            hasher.update(data: data)
        } else {
            let head = try handle.read(upToCount: chunkSize) ?? Data()
            hasher.update(data: head)
            try handle.seek(toOffset: size - UInt64(chunkSize))
            let tail = try handle.readToEnd() ?? Data()
            hasher.update(data: tail)
        }

        let digest = hasher.finalize()
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return "sha256:\(hex)"
    }
}
