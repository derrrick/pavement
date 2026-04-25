import SwiftUI
import AppKit
import CoreImage
import PavementCore

struct PreviewPane: View {
    let sourceURL: URL?

    @State private var fullImage: NSImage?
    @State private var loadingURL: URL?

    var body: some View {
        ZStack {
            Color(white: 0.08)

            if let sourceURL {
                content(for: sourceURL)
            } else {
                ContentUnavailableView(
                    "Select a photo",
                    systemImage: "photo",
                    description: Text("Pick a thumbnail to see the full image.")
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func content(for url: URL) -> some View {
        if let image = fullImage, loadingURL == nil {
            PreviewScrollView(image: image)
        } else if let image = fullImage {
            ZStack {
                PreviewScrollView(image: image)
                ProgressView()
                    .controlSize(.regular)
                    .padding(8)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
            .task(id: url) { await load(url: url) }
        } else {
            ProgressView("Decoding…")
                .task(id: url) { await load(url: url) }
        }
    }

    private func load(url: URL) async {
        loadingURL = url
        let image = await Self.decodeFullPreview(url: url)
        if loadingURL == url {
            fullImage = image
            loadingURL = nil
        }
    }

    private static func decodeFullPreview(url: URL) async -> NSImage? {
        await Task.detached(priority: .userInitiated) {
            let decoder = DecodeStage()
            guard let ciImage = try? decoder.decode(url: url) else { return nil as NSImage? }
            let ctx = PipelineContext.shared.context
            let extent = ciImage.extent
            guard extent.width.isFinite, extent.height.isFinite,
                  let cgImage = ctx.createCGImage(ciImage, from: extent)
            else {
                return nil as NSImage?
            }
            let nsImage = NSImage(cgImage: cgImage, size: extent.size)
            return nsImage
        }.value
    }
}

private struct PreviewScrollView: NSViewRepresentable {
    let image: NSImage

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.borderType = .noBorder
        scrollView.backgroundColor = NSColor(white: 0.08, alpha: 1)
        scrollView.drawsBackground = true
        scrollView.allowsMagnification = true
        scrollView.minMagnification = 0.05
        scrollView.maxMagnification = 8.0
        scrollView.autohidesScrollers = true

        let imageView = ZoomableImageView()
        imageView.imageAlignment = .alignCenter
        imageView.imageScaling = .scaleNone
        imageView.image = image
        imageView.frame = NSRect(origin: .zero, size: image.size)
        scrollView.documentView = imageView

        DispatchQueue.main.async { [weak scrollView] in
            guard let scrollView else { return }
            applyFitToView(scrollView)
        }
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let imageView = scrollView.documentView as? NSImageView else { return }
        let imageChanged = imageView.image !== image
        imageView.image = image
        imageView.frame = NSRect(origin: .zero, size: image.size)
        if imageChanged {
            applyFitToView(scrollView)
        }
    }

    private func applyFitToView(_ scrollView: NSScrollView) {
        guard let documentView = scrollView.documentView else { return }
        let docSize = documentView.frame.size
        let viewportSize = scrollView.contentView.bounds.size
        guard docSize.width > 0, docSize.height > 0,
              viewportSize.width > 0, viewportSize.height > 0 else { return }
        let fit = min(viewportSize.width / docSize.width,
                      viewportSize.height / docSize.height)
        scrollView.magnification = fit
        let center = NSPoint(
            x: (docSize.width - viewportSize.width / fit) / 2,
            y: (docSize.height - viewportSize.height / fit) / 2
        )
        scrollView.contentView.scroll(to: center)
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }
}

private final class ZoomableImageView: NSImageView {
    /// Double-click toggles between fit-to-view and 1:1.
    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2,
           let scrollView = enclosingScrollView {
            let target: CGFloat = abs(scrollView.magnification - 1.0) < 0.01 ? scrollView.minMagnification : 1.0
            let mouse = convert(event.locationInWindow, from: nil)
            scrollView.setMagnification(target, centeredAt: mouse)
        } else {
            super.mouseDown(with: event)
        }
    }
}
