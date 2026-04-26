import SwiftUI
import PavementCore

struct CanvasToolHint: View {
    let tool: CanvasTool
    @Bindable var document: PavementDocument

    var body: some View {
        Group {
            switch tool {
            case .crop:
                Label(document.recipe.operations.crop.enabled ? "Crop active" : "Crop ready", systemImage: "crop")
            case .pan:
                if document.renderedImage != nil {
                    Label("Pan canvas", systemImage: "hand.draw")
                }
            case .zoom:
                Label("Click to zoom", systemImage: "magnifyingglass")
            }
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: Capsule())
    }
}
