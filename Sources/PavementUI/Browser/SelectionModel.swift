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

    /// Number of columns in the current grid layout. BrowserView keeps this
    /// in sync as the window resizes; SelectionModel uses it to translate
    /// up/down arrow keys into linear offsets.
    public var columnCount: Int = 1

    public init() {}

    public func setItems(_ newItems: [SourceItem]) {
        items = newItems
        if let firstURL = newItems.first?.url {
            selection = [firstURL]
            anchorIndex = 0
        } else {
            selection = []
            anchorIndex = nil
        }
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
