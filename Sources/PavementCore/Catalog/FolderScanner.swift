import Foundation

public struct SourceItem: Hashable, Identifiable {
    public let url: URL
    public let type: RAWFileType
    public let fileSize: Int64

    public var id: URL { url }

    public init(url: URL, type: RAWFileType, fileSize: Int64) {
        self.url = url
        self.type = type
        self.fileSize = fileSize
    }
}

public struct FolderScanner {
    /// Top-level subdirectories Pavement manages itself; never returned in a scan.
    public static let ignoredDirectoryNames: Set<String> = ["_pavement", "_exports"]

    public init() {}

    /// Recursively walks `folder`, returning every ingestible source file.
    /// Ignores hidden files, ignored directory names, and unsupported extensions.
    public func scan(folder: URL) throws -> [SourceItem] {
        let fm = FileManager.default
        let resourceKeys: [URLResourceKey] = [.isDirectoryKey, .isHiddenKey, .fileSizeKey]

        guard let enumerator = fm.enumerator(
            at: folder,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles, .producesRelativePathURLs]
        ) else {
            return []
        }

        var items: [SourceItem] = []
        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: Set(resourceKeys))
            if values.isDirectory == true {
                if Self.ignoredDirectoryNames.contains(url.lastPathComponent) {
                    enumerator.skipDescendants()
                }
                continue
            }
            let type = RAWFileType.from(url: url)
            guard type.isIngestible else { continue }
            let size = Int64(values.fileSize ?? 0)
            items.append(SourceItem(url: url.absoluteURL, type: type, fileSize: size))
        }
        return items.sorted { $0.url.path < $1.url.path }
    }
}
