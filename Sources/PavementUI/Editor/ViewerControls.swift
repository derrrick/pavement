import SwiftUI

struct ViewerControls: View {
    @Binding var state: ViewerState

    var body: some View {
        HStack(spacing: 4) {
            Button {
                state.fit()
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
            }
            .help("Fit to view")

            Button {
                state.actualSize()
            } label: {
                Text("100")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .frame(width: 28)
            }
            .help("Actual size")

            Divider()
                .frame(height: 16)

            Button {
                state.zoom(by: 0.8, anchor: CGPoint(x: state.viewportSize.width / 2, y: state.viewportSize.height / 2))
            } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            .help("Zoom out")

            Text("\(state.zoomPercent)%")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 48)

            Button {
                state.zoom(by: 1.25, anchor: CGPoint(x: state.viewportSize.width / 2, y: state.viewportSize.height / 2))
            } label: {
                Image(systemName: "plus.magnifyingglass")
            }
            .help("Zoom in")
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: Capsule())
    }
}
