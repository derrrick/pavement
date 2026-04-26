import AppKit

public enum CanvasTool: String, CaseIterable, Identifiable {
    case crop
    case pan
    case zoom

    public var id: String { rawValue }

    var label: String {
        switch self {
        case .crop: return "Crop"
        case .pan: return "Pan"
        case .zoom: return "Zoom"
        }
    }

    var cursor: NSCursor {
        switch self {
        case .crop: return .crosshair
        case .pan: return .openHand
        case .zoom: return .pointingHand
        }
    }
}
