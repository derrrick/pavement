import SwiftUI
import MetalKit
import CoreImage
import PavementCore

/// MTKView-backed canvas that renders a CIImage fit-to-view via the engine's
/// CIContext. Driven by recipe changes — each updateNSView triggers a draw
/// without spinning a constant 60Hz draw loop.
struct ImageCanvas: NSViewRepresentable {
    let image: CIImage?

    func makeNSView(context: Context) -> MTKView {
        let device = MTLCreateSystemDefaultDevice() ?? PipelineContext.shared.device!
        let view = MTKView(frame: .zero, device: device)
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

    func updateNSView(_ view: MTKView, context: Context) {
        context.coordinator.image = image
        // If the user dragged the window between displays of different
        // gamuts, refresh the layer colorspace. Cheap.
        if let metalLayer = view.layer as? CAMetalLayer {
            metalLayer.colorspace = ColorSpaces.displayP3
        }
        view.setNeedsDisplay(view.bounds)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    @MainActor
    final class Coordinator: NSObject, MTKViewDelegate {
        var image: CIImage?
        var commandQueue: MTLCommandQueue?
        private let backgroundColor = CIColor(red: 0.05, green: 0.05, blue: 0.05)

        nonisolated func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

        nonisolated func draw(in view: MTKView) {
            MainActor.assumeIsolated { drawOnMain(in: view) }
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
                let scale = min(drawableSize.width / extent.width,
                                drawableSize.height / extent.height)
                let scaled = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
                let scaledExtent = scaled.extent
                let dx = (drawableSize.width - scaledExtent.width) / 2 - scaledExtent.minX
                let dy = (drawableSize.height - scaledExtent.height) / 2 - scaledExtent.minY
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
    }
}
