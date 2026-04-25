import Foundation
import CoreImage
import Observation

@Observable
@MainActor
public final class PavementDocument {
    public let source: SourceItem
    public let exif: ExifData?
    public let fingerprint: String

    /// Mutable edit state. Setting this triggers a re-render and schedules an
    /// autosave to the JSON sidecar (250ms debounce).
    public var recipe: EditRecipe {
        didSet {
            guard recipe != oldValue else { return }
            recipe.modifiedAt = EditRecipe.now()
            handleLensCorrectionToggleIfNeeded(oldValue: oldValue)
            renderedImage = renderRecipe()
            scheduleSave()
            scheduleHistogram()
        }
    }

    private func handleLensCorrectionToggleIfNeeded(oldValue: EditRecipe) {
        let oldEnabled = oldValue.operations.lensCorrection.enabled
        let newEnabled = recipe.operations.lensCorrection.enabled
        guard oldEnabled != newEnabled else { return }
        // The new variant might already be cached from an earlier toggle.
        // If not, prime it off-main; renderRecipe falls back to the old
        // variant in the meantime so the canvas never blanks.
        let cache = cachedDecode
        let url = source.url
        if cache.cached(for: url, applyLensCorrection: newEnabled) != nil {
            return
        }
        Task { [weak self] in
            _ = try? await Task.detached(priority: .userInitiated) {
                _ = try cache.image(for: url, applyLensCorrection: newEnabled)
            }.value
            await MainActor.run {
                self?.refreshRender()
            }
        }
    }

    /// Latest rendered preview (post-pipeline). Observers redraw when this changes.
    public private(set) var renderedImage: CIImage?

    /// Latest histogram of the rendered preview. Updated on a 100ms debounce
    /// so slider drags don't rebuild the histogram every frame.
    public private(set) var histogram: Histogram = .empty

    private let cachedDecode: CachedDecode
    private let sidecar = SidecarStore()
    private let pipeline = PipelineGraph()
    private var saveTask: Task<Void, Never>?
    private var histogramTask: Task<Void, Never>?

    public init(
        source: SourceItem,
        recipe: EditRecipe,
        exif: ExifData?,
        fingerprint: String,
        cachedDecode: CachedDecode
    ) {
        self.source = source
        self.exif = exif
        self.fingerprint = fingerprint
        self.recipe = recipe
        self.cachedDecode = cachedDecode
        self.renderedImage = renderRecipe()
    }

    /// Re-render against the current recipe. Used after the cache primes
    /// asynchronously — the document constructed before the bitmap was ready
    /// can call this once decode completes.
    public func refreshRender() {
        renderedImage = renderRecipe()
        scheduleHistogram()
    }

    private func renderRecipe() -> CIImage? {
        let lensEnabled = recipe.operations.lensCorrection.enabled
        // Prefer the matching variant; fall back to the other one while a
        // toggle re-decode is in flight so the canvas never blanks.
        let cached = cachedDecode.cached(for: source.url, applyLensCorrection: lensEnabled)
            ?? cachedDecode.anyCached(for: source.url)
        guard let cached else { return nil }
        var clamped = recipe
        Clamping.clampInPlace(&clamped)
        return pipeline.apply(clamped, to: cached)
    }

    private func scheduleHistogram() {
        histogramTask?.cancel()
        guard let image = renderedImage else { return }
        histogramTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 100_000_000)
                guard !Task.isCancelled else { return }
                let computed = await Task.detached(priority: .userInitiated) {
                    HistogramComputer().compute(image: image)
                }.value
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self?.histogram = computed
                }
            } catch is CancellationError {
                return
            } catch {
                Log.pipeline.error("Histogram failed: \(String(describing: error), privacy: .public)")
            }
        }
    }

    private func scheduleSave() {
        saveTask?.cancel()
        let snapshot = recipe
        let url = source.url
        let store = sidecar
        saveTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 250_000_000)
                guard !Task.isCancelled else { return }
                try store.save(snapshot, for: url)
            } catch is CancellationError {
                return
            } catch {
                Log.document.error("Sidecar save failed for \(url.lastPathComponent, privacy: .public): \(String(describing: error), privacy: .public)")
                _ = self // suppress unused warning
            }
        }
    }
}
