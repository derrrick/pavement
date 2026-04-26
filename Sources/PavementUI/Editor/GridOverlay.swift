import SwiftUI

struct GridOverlay: View {
    let mode: GridOverlayMode

    var body: some View {
        Canvas { ctx, size in
            var path = Path()
            switch mode {
            case .off:
                return
            case .thirds:
                addVerticalLines([1 / 3, 2 / 3], size: size, to: &path)
                addHorizontalLines([1 / 3, 2 / 3], size: size, to: &path)
            case .golden:
                let a = 0.382
                let b = 0.618
                addVerticalLines([a, b], size: size, to: &path)
                addHorizontalLines([a, b], size: size, to: &path)
            case .square:
                addVerticalLines([0.25, 0.5, 0.75], size: size, to: &path)
                addHorizontalLines([0.25, 0.5, 0.75], size: size, to: &path)
            case .diagonals:
                path.move(to: .zero)
                path.addLine(to: CGPoint(x: size.width, y: size.height))
                path.move(to: CGPoint(x: size.width, y: 0))
                path.addLine(to: CGPoint(x: 0, y: size.height))
                addVerticalLines([0.5], size: size, to: &path)
                addHorizontalLines([0.5], size: size, to: &path)
            }
            ctx.stroke(
                path,
                with: .color(.white.opacity(0.48)),
                style: StrokeStyle(lineWidth: 0.7, lineCap: .round, dash: [4, 4])
            )
        }
        .allowsHitTesting(false)
    }

    private func addVerticalLines(_ fractions: [Double], size: CGSize, to path: inout Path) {
        for fraction in fractions {
            let x = size.width * fraction
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
        }
    }

    private func addHorizontalLines(_ fractions: [Double], size: CGSize, to path: inout Path) {
        for fraction in fractions {
            let y = size.height * fraction
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
        }
    }
}

struct ImageGridOverlay: View {
    let mode: GridOverlayMode
    let viewerState: ViewerState
    let imageExtent: CGRect

    var body: some View {
        GeometryReader { geometry in
            let rect = imageRect(in: geometry.size)
            GridOverlay(mode: mode)
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
                .clipShape(Rectangle())
                .overlay(
                    Rectangle()
                        .stroke(Color.white.opacity(0.24), lineWidth: 0.7)
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                )
        }
        .allowsHitTesting(false)
    }

    private func imageRect(in viewSize: CGSize) -> CGRect {
        guard imageExtent.width > 0, imageExtent.height > 0 else { return .zero }
        let xRatio = viewerState.viewportSize.width > 0 ? viewSize.width / viewerState.viewportSize.width : 1
        let yRatio = viewerState.viewportSize.height > 0 ? viewSize.height / viewerState.viewportSize.height : 1
        let width = imageExtent.width * viewerState.scale * xRatio
        let height = imageExtent.height * viewerState.scale * yRatio
        let center = CGPoint(
            x: viewSize.width / 2 + viewerState.panOffset.width * xRatio,
            y: viewSize.height / 2 - viewerState.panOffset.height * yRatio
        )
        return CGRect(x: center.x - width / 2, y: center.y - height / 2, width: width, height: height)
    }
}
