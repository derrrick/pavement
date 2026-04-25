import Foundation

public struct SidecarStore {
    public init() {}

    /// `<source>.pavement.json` next to the source file.
    public static func sidecarURL(for source: URL) -> URL {
        source.appendingPathExtension("pavement.json")
    }

    /// Returns the recipe at `<source>.pavement.json`, or nil if absent.
    public func load(for source: URL) throws -> EditRecipe? {
        let url = Self.sidecarURL(for: source)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        return try EditRecipe.makeDecoder().decode(EditRecipe.self, from: data)
    }

    /// Atomic write: encode to <sidecar>.tmp, then rename to <sidecar>.
    /// rename(2) is atomic on the same filesystem; partial writes never appear
    /// at the destination path.
    public func save(_ recipe: EditRecipe, for source: URL) throws {
        let target = Self.sidecarURL(for: source)
        let tmp = target.deletingLastPathComponent()
            .appendingPathComponent(target.lastPathComponent + ".tmp")

        let data = try EditRecipe.makeEncoder().encode(recipe)
        try data.write(to: tmp, options: .atomic)

        if FileManager.default.fileExists(atPath: target.path) {
            try FileManager.default.removeItem(at: target)
        }
        try FileManager.default.moveItem(at: tmp, to: target)
    }
}
