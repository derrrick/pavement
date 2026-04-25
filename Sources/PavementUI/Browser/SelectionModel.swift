import Foundation
import Observation
import PavementCore

public enum SelectionMove {
    case left
    case right
    case up
    case down
}

@Observable
@MainActor
public final class SelectionModel {
    public private(set) var items: [SourceItem] = []
    public private(set) var selection: Set<URL> = []
    public private(set) var anchorIndex: Int?

    /// Independent of `selection` — items the user has flagged for batch
    /// operations (export, AI run, etc.) by ticking the thumbnail checkbox.
    /// Survives selection changes; cleared on folder reload.
    public var batchSelection: Set<URL> = []

    /// Per-source ratings (0..5). Backed by sidecar files when an item is
    /// loaded; cached here so the contact sheet can render stars without
    /// blocking on disk per cell. Updated when the user clicks a star.
    public var ratings: [URL: Int] = [:]

    /// Number of columns in the current grid layout. BrowserView keeps this
    /// in sync as the window resizes; SelectionModel uses it to translate
    /// up/down arrow keys into linear offsets.
    public var columnCount: Int = 1

    public init() {}

    public func setItems(_ newItems: [SourceItem]) {
        items = newItems
        batchSelection = []
        if let firstURL = newItems.first?.url {
            selection = [firstURL]
            anchorIndex = 0
        } else {
            selection = []
            anchorIndex = nil
        }
    }

    public func toggleBatchSelection(for url: URL) {
        if batchSelection.contains(url) {
            batchSelection.remove(url)
        } else {
            batchSelection.insert(url)
        }
    }

    public func clearBatchSelection() {
        batchSelection.removeAll()
    }

    public func selectAllForBatch() {
        batchSelection = Set(items.map(\.url))
    }

    public func setRating(_ rating: Int, for url: URL) {
        let clamped = max(0, min(5, rating))
        if clamped == 0 {
            ratings.removeValue(forKey: url)
        } else {
            ratings[url] = clamped
        }
    }

    public func setRatingForCurrent(_ rating: Int) {
        guard let url = primarySelectionURL else { return }
        setRating(rating, for: url)
    }

    public func rating(for url: URL) -> Int {
        ratings[url] ?? 0
    }

    public var primarySelectionURL: URL? {
        guard let index = anchorIndex, items.indices.contains(index) else {
            return selection.first
        }
        return items[index].url
    }

    public func handleClick(at index: Int, shift: Bool, command: Bool) {
        guard items.indices.contains(index) else { return }
        let clickedURL = items[index].url

        if shift, let anchor = anchorIndex {
            let lower = min(anchor, index)
            let upper = max(anchor, index)
            selection = Set(items[lower...upper].map { $0.url })
            return
        }

        if command {
            if selection.contains(clickedURL) {
                selection.remove(clickedURL)
            } else {
                selection.insert(clickedURL)
            }
            anchorIndex = index
            return
        }

        selection = [clickedURL]
        anchorIndex = index
    }

    public func move(_ direction: SelectionMove) {
        guard !items.isEmpty else { return }
        let current = anchorIndex ?? 0
        let target: Int
        switch direction {
        case .left:  target = max(0, current - 1)
        case .right: target = min(items.count - 1, current + 1)
        case .up:    target = max(0, current - max(1, columnCount))
        case .down:  target = min(items.count - 1, current + max(1, columnCount))
        }
        selection = [items[target].url]
        anchorIndex = target
    }

    public func selectAll() {
        selection = Set(items.map { $0.url })
    }
}
