import SwiftUI
import UniformTypeIdentifiers
import AppKit
import CoreImage
import PavementCore

struct MatchLookPanel: View {
    @Bindable var document: PavementDocument

    @State private var referenceImage: NSImage?
    @State private var referenceStats: ImageStatistics?
    @State private var isAnalyzing = false
    @State private var intensity: Double = 1.0
    @State private var dropTargeted = false
    @State private var statusMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            dropZone

            if referenceImage != nil {
                HStack {
                    Text("Intensity").font(.caption)
                    Slider(value: $intensity, in: 0...1, step: 0.05)
                    Text(String(format: "%.0f%%", intensity * 100))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 38, alignment: .trailing)
                }
                HStack {
                    Button("Apply") { applyMatch() }
                        .buttonStyle(.borderedProminent)
                        .disabled(referenceStats == nil || isAnalyzing)
                    Button("Clear") {
                        referenceImage = nil
                        referenceStats = nil
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                }
            }

            if let statusMessage {
                Text(statusMessage)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text("Drop a reference JPEG to derive a recipe of edits that pulls this image's color and tone toward the reference. Crop and lens correction are preserved.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.top, 2)
        }
    }

    private var dropZone: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(
                    style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                )
                .foregroundStyle(dropTargeted ? Color.accentColor : Color.white.opacity(0.18))
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(dropTargeted ? Color.accentColor.opacity(0.08) : Color(white: 0.10))
                )

            if let image = referenceImage {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .padding(2)
            } else {
                VStack(spacing: 4) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    Text(isAnalyzing ? "Analyzing…" : "Drop reference image")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(height: 140)
        .onDrop(of: [.fileURL, .image], isTargeted: $dropTargeted) { providers in
            handleDrop(providers: providers)
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        let identifiers = provider.registeredTypeIdentifiers

        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                guard let data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                Task { @MainActor in
                    await loadReference(from: url)
                }
            }
            return true
        }
        if let imageType = identifiers.first(where: { UTType($0)?.conforms(to: .image) == true }) {
            provider.loadDataRepresentation(forTypeIdentifier: imageType) { data, _ in
                guard let data, let image = NSImage(data: data) else { return }
                Task { @MainActor in
                    await analyze(image: image)
                }
            }
            return true
        }
        return false
    }

    private func loadReference(from url: URL) async {
        guard let image = NSImage(contentsOf: url) else {
            statusMessage = "Couldn't open that reference image."
            return
        }
        await analyze(image: image, url: url)
    }

    private func analyze(image: NSImage, url: URL? = nil) async {
        referenceImage = image
        referenceStats = nil
        statusMessage = nil
        isAnalyzing = true
        let stats = await Task.detached(priority: .userInitiated) {
            let ci: CIImage?
            if let url {
                ci = CIImage(contentsOf: url)
            } else {
                ci = Self.makeCIImage(from: image)
            }
            guard let ci else { return nil as ImageStatistics? }
            return ImageStatisticsCalculator.compute(from: ci)
        }.value
        referenceStats = stats
        statusMessage = stats == nil ? "Couldn't analyze that reference image." : "Reference analyzed."
        isAnalyzing = false
    }

    private func applyMatch() {
        guard let refStats = referenceStats else {
            statusMessage = "Drop a reference image first."
            return
        }
        guard document.statisticsForMatching() != nil else {
            statusMessage = "Current image is still loading."
            return
        }
        document.applyMatchedLook(reference: refStats, intensity: intensity)
        statusMessage = "Matched look applied."
    }

    nonisolated private static func makeCIImage(from image: NSImage) -> CIImage? {
        var rect = CGRect(origin: .zero, size: image.size)
        guard let cgImage = image.cgImage(forProposedRect: &rect, context: nil, hints: nil) else {
            return nil
        }
        return CIImage(cgImage: cgImage)
    }
}
