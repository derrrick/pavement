import CoreGraphics

enum ViewerZoomMode: Equatable {
    case fit
    case actualSize
    case custom
}

struct ViewerState: Equatable {
    var zoomMode: ViewerZoomMode = .fit
    var scale: CGFloat = 1
    var panOffset: CGSize = .zero
    var viewportSize: CGSize = .zero
    var imageExtent: CGRect = .zero

    var imageSize: CGSize { imageExtent.size }

    var zoomPercent: Int {
        max(1, Int((scale * 100).rounded()))
    }

    mutating func updateImage(extent: CGRect?, viewport: CGSize) {
        viewportSize = viewport
        imageExtent = extent ?? .zero
        guard hasRenderableImage else {
            scale = 1
            panOffset = .zero
            zoomMode = .fit
            return
        }
        switch zoomMode {
        case .fit:
            scale = Self.fitScale(imageSize: imageSize, viewport: viewportSize)
            panOffset = .zero
        case .actualSize:
            scale = 1
            clampPan()
        case .custom:
            scale = Self.clampedScale(scale)
            clampPan()
        }
    }

    mutating func fit() {
        zoomMode = .fit
        scale = Self.fitScale(imageSize: imageSize, viewport: viewportSize)
        panOffset = .zero
    }

    mutating func actualSize() {
        zoomMode = .actualSize
        scale = 1
        clampPan()
    }

    mutating func toggleFitActual() {
        if zoomMode == .actualSize || abs(scale - 1) < 0.001 {
            fit()
        } else {
            actualSize()
        }
    }

    mutating func zoom(by factor: CGFloat, anchor: CGPoint? = nil) {
        guard hasRenderableImage, factor.isFinite, factor > 0 else { return }
        let oldScale = scale
        let newScale = Self.clampedScale(scale * factor)
        guard abs(newScale - oldScale) > 0.0001 else { return }

        if let anchor {
            let center = CGPoint(x: viewportSize.width / 2, y: viewportSize.height / 2)
            let anchorVector = CGPoint(x: anchor.x - center.x, y: anchor.y - center.y)
            let imagePoint = CGPoint(
                x: (anchorVector.x - panOffset.width) / oldScale,
                y: (anchorVector.y - panOffset.height) / oldScale
            )
            panOffset = CGSize(
                width: anchorVector.x - imagePoint.x * newScale,
                height: anchorVector.y - imagePoint.y * newScale
            )
        }

        scale = newScale
        zoomMode = abs(scale - Self.fitScale(imageSize: imageSize, viewport: viewportSize)) < 0.001 ? .fit : .custom
        clampPan()
    }

    mutating func pan(by delta: CGSize) {
        guard hasRenderableImage else { return }
        panOffset.width += delta.width
        panOffset.height += delta.height
        if zoomMode == .fit {
            zoomMode = .custom
        }
        clampPan()
    }

    mutating func clampPan() {
        guard hasRenderableImage else {
            panOffset = .zero
            return
        }

        let scaledWidth = imageSize.width * scale
        let scaledHeight = imageSize.height * scale
        let maxX = max(0, (scaledWidth - viewportSize.width) / 2)
        let maxY = max(0, (scaledHeight - viewportSize.height) / 2)
        panOffset.width = min(max(panOffset.width, -maxX), maxX)
        panOffset.height = min(max(panOffset.height, -maxY), maxY)
    }

    static func fitScale(imageSize: CGSize, viewport: CGSize) -> CGFloat {
        guard imageSize.width > 0, imageSize.height > 0, viewport.width > 0, viewport.height > 0 else { return 1 }
        return min(viewport.width / imageSize.width, viewport.height / imageSize.height)
    }

    private var hasRenderableImage: Bool {
        imageExtent.width.isFinite && imageExtent.height.isFinite && imageExtent.width > 0 && imageExtent.height > 0
            && viewportSize.width.isFinite && viewportSize.height.isFinite && viewportSize.width > 0 && viewportSize.height > 0
    }

    private static func clampedScale(_ value: CGFloat) -> CGFloat {
        min(max(value, 0.05), 8)
    }
}
