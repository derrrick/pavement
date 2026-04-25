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
        if identifiers.contains(UTType.fileURL.identifier) {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
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
        guard let image = NSImage(contentsOf: url) else { return }
        await analyze(image: image)
    }

    private func analyze(image: NSImage) async {
        referenceImage = image
        isAnalyzing = true
        let stats = await Task.detached(priority: .userInitiated) {
            guard let tiff = image.tiffRepresentation,
                  let ci = CIImage(data: tiff) else { return nil as ImageStatistics? }
            return ImageStatisticsCalculator.compute(from: ci)
        }.value
        referenceStats = stats
        isAnalyzing = false
    }

    private func applyMatch() {
        guard let refStats = referenceStats,
              let renderedSource = document.renderedImage ?? document.cachedSourceForMatching else {
            return
        }
        Task {
            let currentStats = await Task.detached(priority: .userInitiated) {
                ImageStatisticsCalculator.compute(from: renderedSource)
            }.value
            let derived = MatchLook.deriveOperations(
                from: refStats,
                current: currentStats,
                intensity: intensity
            )
            // Replace operation blocks the match drives; preserve crop + lens.
            await MainActor.run {
                var newOps = derived
                newOps.crop = document.recipe.operations.crop
                newOps.lensCorrection = document.recipe.operations.lensCorrection
                document.recipe.operations = newOps
            }
        }
    }
}

extension PavementDocument {
    /// Convenience: if no rendered image is available yet, return any
    /// cached decode for the source URL so MatchLook still has something
    /// to compute statistics from.
    @MainActor
    var cachedSourceForMatching: CIImage? {
        renderedImage
    }
}
