import Foundation

public enum GridOverlayMode: String, CaseIterable, Identifiable {
    case off
    case thirds
    case golden
    case square
    case diagonals

    public var id: String { rawValue }

    var label: String {
        switch self {
        case .off: return "Grid Off"
        case .thirds: return "Thirds"
        case .golden: return "Golden"
        case .square: return "Square"
        case .diagonals: return "Diagonals"
        }
    }

    var systemImage: String {
        switch self {
        case .off: return "grid"
        case .thirds: return "grid"
        case .golden: return "rectangle.split.3x3"
        case .square: return "square.grid.3x3"
        case .diagonals: return "line.diagonal"
        }
    }

    func next() -> GridOverlayMode {
        let modes = Self.allCases
        guard let index = modes.firstIndex(of: self) else { return .thirds }
        return modes[(index + 1) % modes.count]
    }
}
