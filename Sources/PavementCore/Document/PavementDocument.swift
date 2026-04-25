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
            renderedImage = renderRecipe()
            scheduleSave()
        }
    }

    /// Latest rendered preview (post-pipeline). Observers redraw when this changes.
    public private(set) var renderedImage: CIImage?

    private let cachedDecode: CachedDecode
    private let sidecar = SidecarStore()
    private let pipeline = PipelineGraph()
    private var saveTask: Task<Void, Never>?

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
    }

    private func renderRecipe() -> CIImage? {
        guard let cached = cachedDecode.cached(for: source.url) else { return nil }
        var clamped = recipe
        Clamping.clampInPlace(&clamped)
        return pipeline.apply(clamped, to: cached)
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
