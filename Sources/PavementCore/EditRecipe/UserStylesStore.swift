import Foundation

/// Disk-backed library of user-created and imported styles. Lives in
/// `~/Library/Application Support/Pavement/styles.json`. Read once per
/// app launch; writes are atomic via temp-rename.
@MainActor
public final class UserStylesStore: ObservableObject {
    public static let shared = UserStylesStore()

    @Published public private(set) var styles: [Style] = []

    private let storeURL: URL
    private let queue = DispatchQueue(label: "app.pavement.styles", qos: .userInitiated)

    public init(storeURL: URL? = nil) {
        if let storeURL {
            self.storeURL = storeURL
        } else {
            let support = (try? FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )) ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
            let dir = support.appendingPathComponent("Pavement", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            self.storeURL = dir.appendingPathComponent("styles.json")
        }
        load()
    }

    public func add(_ style: Style) {
        var updated = styles
        if let idx = updated.firstIndex(where: { $0.id == style.id }) {
            updated[idx] = style
        } else {
            updated.append(style)
        }
        styles = updated.sorted(by: { $0.createdAt < $1.createdAt })
        save()
    }

    public func remove(id: String) {
        styles.removeAll { $0.id == id }
        save()
    }

    public func rename(id: String, to newName: String) {
        guard let idx = styles.firstIndex(where: { $0.id == id }) else { return }
        styles[idx].name = newName
        save()
    }

    public func duplicate(id: String) {
        guard let original = styles.first(where: { $0.id == id }) else { return }
        var copy = original
        copy.id = UUID().uuidString
        copy.name = "\(original.name) Copy"
        copy.createdAt = EditRecipe.now()
        styles.append(copy)
        save()
    }

    public func style(withId id: String) -> Style? {
        styles.first { $0.id == id }
    }

    public func styles(in category: String) -> [Style] {
        styles.filter { $0.category == category }
    }

    public var categories: [String] {
        Array(Set(styles.map(\.category))).sorted()
    }

    // MARK: - Disk

    private func load() {
        guard FileManager.default.fileExists(atPath: storeURL.path) else { return }
        do {
            let data = try Data(contentsOf: storeURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let loaded = try decoder.decode([Style].self, from: data)
            styles = loaded
        } catch {
            Log.document.error("Failed to load styles: \(String(describing: error), privacy: .public)")
        }
    }

    private func save() {
        let snapshot = styles
        let url = storeURL
        queue.async {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            do {
                let data = try encoder.encode(snapshot)
                let tmp = url.deletingLastPathComponent()
                    .appendingPathComponent(url.lastPathComponent + ".tmp")
                try data.write(to: tmp, options: .atomic)
                if FileManager.default.fileExists(atPath: url.path) {
                    try FileManager.default.removeItem(at: url)
                }
                try FileManager.default.moveItem(at: tmp, to: url)
            } catch {
                Log.document.error("Failed to save styles: \(String(describing: error), privacy: .public)")
            }
        }
    }
}
