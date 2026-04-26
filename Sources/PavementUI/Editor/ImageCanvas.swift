import SwiftUI
import MetalKit
import CoreImage
import PavementCore

/// MTKView-backed canvas that renders a CIImage fit-to-view via the engine's
/// CIContext. Driven by recipe changes — each updateNSView triggers a draw
/// without spinning a constant 60Hz draw loop.
struct ImageCanvas: NSViewRepresentable {
    let image: CIImage?
    @Binding var viewerState: ViewerState
    let activeTool: CanvasTool

    func makeNSView(context: Context) -> CanvasMTKView {
        let device = MTLCreateSystemDefaultDevice() ?? PipelineContext.shared.device!
        let view = CanvasMTKView(frame: .zero, device: device)
        view.colorPixelFormat = .rgba16Float
        view.framebufferOnly = false
        view.enableSetNeedsDisplay = true
        view.isPaused = true
        view.clearColor = MTLClearColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 1)
        view.delegate = context.coordinator
        context.coordinator.commandQueue = device.makeCommandQueue()

        // Tell WindowServer the float values landing in this drawable are
        // Display-P3-encoded. Without this, the layer is treated as sRGB
        // and on-screen color drifts compared to a P3-tagged JPEG export
        // (the exact bug PLAN.md §10 risk #3 warned about). `colorspace`
        // lives on CAMetalLayer specifically — generic CALayer doesn't
        // have it.
        view.wantsLayer = true
        if let metalLayer = view.layer as? CAMetalLayer {
            metalLayer.colorspace = ColorSpaces.displayP3
            metalLayer.wantsExtendedDynamicRangeContent = true
            metalLayer.pixelFormat = .rgba16Float
        }
        return view
    }

    func updateNSView(_ view: CanvasMTKView, context: Context) {
        context.coordinator.image = image
        context.coordinator.viewerState = $viewerState
        context.coordinator.activeTool = activeTool
        view.interactionDelegate = context.coordinator
        view.activeTool = activeTool
        context.coordinator.syncViewerState(for: view)
        // If the user dragged the window between displays of different
        // gamuts, refresh the layer colorspace. Cheap.
        if let metalLayer = view.layer as? CAMetalLayer {
            metalLayer.colorspace = ColorSpaces.displayP3
        }
        view.setNeedsDisplay(view.bounds)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    @MainActor
    final class Coordinator: NSObject, MTKViewDelegate, CanvasInteractionDelegate {
        var image: CIImage?
        var commandQueue: MTLCommandQueue?
        var viewerState: Binding<ViewerState>?
        var activeTool: CanvasTool = .pan
        private let backgroundColor = CIColor(red: 0.05, green: 0.05, blue: 0.05)

        nonisolated func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            MainActor.assumeIsolated {
                guard let canvas = view as? CanvasMTKView else { return }
                syncViewerState(for: canvas)
            }
        }

        nonisolated func draw(in view: MTKView) {
            MainActor.assumeIsolated { drawOnMain(in: view) }
        }

        func syncViewerState(for view: CanvasMTKView) {
            guard var state = viewerState?.wrappedValue else { return }
            state.updateImage(extent: image?.extent, viewport: view.drawableSize)
            viewerState?.wrappedValue = state
        }

        private func drawOnMain(in view: MTKView) {
            guard let drawable = view.currentDrawable,
                  let queue = commandQueue,
                  let buffer = queue.makeCommandBuffer() else { return }

            let drawableSize = view.drawableSize
            guard drawableSize.width > 0, drawableSize.height > 0 else { return }

            let bg = CIImage(color: backgroundColor)
                .cropped(to: CGRect(origin: .zero, size: drawableSize))

            let composite: CIImage
            if let image,
               image.extent.width.isFinite, image.extent.height.isFinite,
               image.extent.width > 0, image.extent.height > 0 {
                let extent = image.extent
                let state = viewerState?.wrappedValue ?? ViewerState()
                let scale = state.scale.isFinite && state.scale > 0
                    ? state.scale
                    : ViewerState.fitScale(imageSize: extent.size, viewport: drawableSize)
                let scaled = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
                let scaledExtent = scaled.extent
                let dx = (drawableSize.width - scaledExtent.width) / 2 - scaledExtent.minX + state.panOffset.width
                let dy = (drawableSize.height - scaledExtent.height) / 2 - scaledExtent.minY + state.panOffset.height
                let centered = scaled.transformed(by: CGAffineTransform(translationX: dx, y: dy))
                composite = centered.composited(over: bg)
            } else {
                composite = bg
            }

            PipelineContext.shared.context.render(
                composite,
                to: drawable.texture,
                commandBuffer: buffer,
                bounds: CGRect(origin: .zero, size: drawableSize),
                colorSpace: ColorSpaces.displayP3
            )

            buffer.present(drawable)
            buffer.commit()
        }

        func canvasDidDoubleClick(_ view: CanvasMTKView) {
            guard var state = viewerState?.wrappedValue else { return }
            state.toggleFitActual()
            viewerState?.wrappedValue = state
            view.setNeedsDisplay(view.bounds)
        }

        func canvas(_ view: CanvasMTKView, didScroll event: NSEvent) {
            guard var state = viewerState?.wrappedValue else { return }
            // If the canvas hasn't seen its first sync yet (image just
            // arrived but updateNSView pass hasn't run), drive the sync
            // here so the first scroll event is honoured instead of
            // silently dropped because hasRenderableImage is false.
            if state.imageExtent.width == 0 || state.viewportSize.width == 0 {
                state.updateImage(extent: image?.extent, viewport: view.drawableSize)
            }

            // Tuned for "feels right":
            //   - Mouse wheel (non-precise): ~10% per click in the
            //     scroll direction — matches Photoshop / Capture One.
            //   - Trackpad (precise): ~1% per scroll-delta unit, giving
            //     smooth analog control over the whole 0.05x..8x range.
            // Previous 1.0025 base produced <2% per wheel click which
            // was easy to mistake for "not working at all."
            let precise = event.hasPreciseScrollingDeltas
            let raw = precise ? event.scrollingDeltaY : event.deltaY
            guard raw != 0 else { return }
            let factor: CGFloat
            if precise {
                factor = pow(1.01, raw)
            } else {
                // Non-precise wheels send small absolute deltas (often 1
                // or fractional) — driving them through pow(1.10, raw)
                // gives a consistent 10%-ish change per click in the
                // scroll direction without runaway acceleration on
                // high-momentum scrolls.
                factor = pow(1.10, raw)
            }

            state.zoom(by: factor, anchor: drawablePoint(for: event.locationInWindow, in: view))
            viewerState?.wrappedValue = state
            view.setNeedsDisplay(view.bounds)
        }

        func canvas(_ view: CanvasMTKView, didMagnify event: NSEvent) {
            guard var state = viewerState?.wrappedValue else { return }
            state.zoom(by: 1 + event.magnification, anchor: drawablePoint(for: event.locationInWindow, in: view))
            viewerState?.wrappedValue = state
            view.setNeedsDisplay(view.bounds)
        }

        func canvas(_ view: CanvasMTKView, didDrag delta: CGSize) {
            guard activeTool == .pan || activeTool == .crop else { return }
            guard var state = viewerState?.wrappedValue else { return }
            let scaleX = view.bounds.width > 0 ? view.drawableSize.width / view.bounds.width : 1
            let scaleY = view.bounds.height > 0 ? view.drawableSize.height / view.bounds.height : 1
            state.pan(by: CGSize(width: delta.width * scaleX, height: delta.height * scaleY))
            viewerState?.wrappedValue = state
            view.setNeedsDisplay(view.bounds)
        }

        func canvas(_ view: CanvasMTKView, didClick event: NSEvent) {
            guard activeTool == .zoom, event.clickCount == 1 else { return }
            // Zoom in. Option-click also zooms out for keyboard parity.
            zoom(in: !event.modifierFlags.contains(.option), event: event, view: view)
        }

        func canvas(_ view: CanvasMTKView, didRightClick event: NSEvent) {
            guard activeTool == .zoom else { return }
            // Capture-One convention — left=in, right=out — so the user
            // never has to reach for a modifier key while bracketing zoom.
            zoom(in: false, event: event, view: view)
        }

        private func zoom(in zoomingIn: Bool, event: NSEvent, view: CanvasMTKView) {
            guard var state = viewerState?.wrappedValue else { return }
            let factor: CGFloat = zoomingIn ? 1.25 : 0.8
            state.zoom(by: factor, anchor: drawablePoint(for: event.locationInWindow, in: view))
            viewerState?.wrappedValue = state
            view.setNeedsDisplay(view.bounds)
        }

        private func drawablePoint(for windowPoint: CGPoint, in view: CanvasMTKView) -> CGPoint {
            let local = view.convert(windowPoint, from: nil)
            let scaleX = view.bounds.width > 0 ? view.drawableSize.width / view.bounds.width : 1
            let scaleY = view.bounds.height > 0 ? view.drawableSize.height / view.bounds.height : 1
            return CGPoint(x: local.x * scaleX, y: local.y * scaleY)
        }
    }
}

@MainActor
protocol CanvasInteractionDelegate: AnyObject {
    func canvasDidDoubleClick(_ view: CanvasMTKView)
    func canvas(_ view: CanvasMTKView, didClick event: NSEvent)
    func canvas(_ view: CanvasMTKView, didRightClick event: NSEvent)
    func canvas(_ view: CanvasMTKView, didScroll event: NSEvent)
    func canvas(_ view: CanvasMTKView, didMagnify event: NSEvent)
    func canvas(_ view: CanvasMTKView, didDrag delta: CGSize)
}

@MainActor
final class CanvasMTKView: MTKView {
    weak var interactionDelegate: CanvasInteractionDelegate?
    var activeTool: CanvasTool = .pan {
        didSet { updateCursor() }
    }
    private var lastDragLocation: CGPoint?

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        lastDragLocation = convert(event.locationInWindow, from: nil)
        if event.clickCount == 2 {
            interactionDelegate?.canvasDidDoubleClick(self)
        } else {
            interactionDelegate?.canvas(self, didClick: event)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        if let lastDragLocation {
            interactionDelegate?.canvas(
                self,
                didDrag: CGSize(width: location.x - lastDragLocation.x, height: location.y - lastDragLocation.y)
            )
        }
        lastDragLocation = location
    }

    override func mouseUp(with event: NSEvent) {
        lastDragLocation = nil
    }

    override func rightMouseDown(with event: NSEvent) {
        // When the zoom tool is active, intercept right-click so the
        // system context menu doesn't appear and the click reaches the
        // delegate as a zoom-out signal. For other tools we let the
        // default behaviour through.
        if activeTool == .zoom {
            window?.makeFirstResponder(self)
            interactionDelegate?.canvas(self, didRightClick: event)
        } else {
            super.rightMouseDown(with: event)
        }
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        // Suppress the context menu while zoom is active so right-click
        // can be repurposed for zoom-out.
        activeTool == .zoom ? nil : super.menu(for: event)
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: activeTool.cursor)
    }

    private func updateCursor() {
        window?.invalidateCursorRects(for: self)
        activeTool.cursor.set()
    }

    override func scrollWheel(with event: NSEvent) {
        interactionDelegate?.canvas(self, didScroll: event)
    }

    override func magnify(with event: NSEvent) {
        interactionDelegate?.canvas(self, didMagnify: event)
    }
}
