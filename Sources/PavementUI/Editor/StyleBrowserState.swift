import Foundation
import Observation
import PavementCore

enum StyleBrowserCategory: String, CaseIterable, Identifiable {
    case builtIn = "Built-in"
    case user = "User"
    case lightroom = "Lightroom"
    case lut = "LUT"
    case favorites = "Favorites"
    case recent = "Recent"

    var id: String { rawValue }
}

enum StyleBrowserItem: Identifiable, Equatable {
    case preset(Preset)
    case style(Style)

    var id: String {
        switch self {
        case .preset(let preset): return "preset:\(preset.id)"
        case .style(let style): return "style:\(style.id)"
        }
    }

    var name: String {
        switch self {
        case .preset(let preset): return preset.name
        case .style(let style): return style.name
        }
    }

    var category: String {
        switch self {
        case .preset(let preset): return preset.category
        case .style(let style): return style.category
        }
    }

    var description: String {
        switch self {
        case .preset(let preset): return preset.description
        case .style(let style): return style.description
        }
    }

    var hasLUT: Bool {
        if case .style(let style) = self { return style.lut != nil }
        return false
    }
}

@Observable
final class StyleBrowserState {
    var selectedCategory: StyleBrowserCategory = .builtIn
    var searchText = ""
    var previewedStyleID: String?
    var amount: Double {
        didSet {
            amount = min(max(amount, 0), 1)
            defaults.set(amount, forKey: Self.amountKey)
        }
    }

    private(set) var favorites: Set<String>
    private(set) var recentStyleIDs: [String]
    private let defaults: UserDefaults

    static let favoritesKey = "pavement.styleBrowser.favorites"
    static let recentKey = "pavement.styleBrowser.recent"
    static let amountKey = "pavement.styleBrowser.amount"
    private static let maxRecent = 8

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.amount = defaults.object(forKey: Self.amountKey) as? Double ?? 1.0
        self.favorites = Set(defaults.stringArray(forKey: Self.favoritesKey) ?? [])
        self.recentStyleIDs = defaults.stringArray(forKey: Self.recentKey) ?? []
    }

    func isFavorite(_ item: StyleBrowserItem) -> Bool {
        favorites.contains(item.id)
    }

    func toggleFavorite(_ item: StyleBrowserItem) {
        if favorites.contains(item.id) {
            favorites.remove(item.id)
        } else {
            favorites.insert(item.id)
        }
        persistFavorites()
    }

    func recordApply(_ item: StyleBrowserItem) {
        recentStyleIDs.removeAll { $0 == item.id }
        recentStyleIDs.insert(item.id, at: 0)
        if recentStyleIDs.count > Self.maxRecent {
            recentStyleIDs.removeLast(recentStyleIDs.count - Self.maxRecent)
        }
        defaults.set(recentStyleIDs, forKey: Self.recentKey)
    }

    func filteredItems(builtIns: [Preset], styles: [Style]) -> [StyleBrowserItem] {
        let all = builtIns.map(StyleBrowserItem.preset) + styles.map(StyleBrowserItem.style)
        let scoped: [StyleBrowserItem]
        switch selectedCategory {
        case .builtIn:
            scoped = builtIns.filter { $0.category != "Reset" }.map(StyleBrowserItem.preset)
        case .user:
            scoped = styles.filter { $0.category == "User" }.map(StyleBrowserItem.style)
        case .lightroom:
            scoped = styles.filter { $0.category == "Lightroom" }.map(StyleBrowserItem.style)
        case .lut:
            scoped = styles.filter { $0.category == "LUT" || $0.lut != nil }.map(StyleBrowserItem.style)
        case .favorites:
            scoped = all.filter { favorites.contains($0.id) }
        case .recent:
            scoped = recentStyleIDs.compactMap { id in all.first { $0.id == id } }
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return scoped }
        return scoped.filter {
            $0.name.lowercased().contains(query)
                || $0.category.lowercased().contains(query)
                || $0.description.lowercased().contains(query)
        }
    }

    private func persistFavorites() {
        defaults.set(Array(favorites).sorted(), forKey: Self.favoritesKey)
    }
}
