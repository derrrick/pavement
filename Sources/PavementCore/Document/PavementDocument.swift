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
            previewRecipe = nil
            if !suppressUndoCapture {
                undoStack.append(oldValue)
                if undoStack.count > maxUndoDepth {
                    undoStack.removeFirst()
                }
                redoStack.removeAll()
                updateUndoAvailability()
            }
            recipe.modifiedAt = EditRecipe.now()
            handleLensCorrectionToggleIfNeeded(oldValue: oldValue)
            renderedImage = renderRecipe()
            scheduleSave()
            scheduleHistogram()
        }
    }

    /// Linear undo/redo stacks scoped to this document. Each recipe mutation
    /// pushes the previous value onto undoStack; undo() pops it and pushes
    /// the current value onto redoStack. Manipulations performed by the
    /// stacks themselves are gated by `suppressUndoCapture` so they don't
    /// recurse.
    private var undoStack: [EditRecipe] = []
    private var redoStack: [EditRecipe] = []
    private var suppressUndoCapture = false
    private let maxUndoDepth = 32

    public private(set) var canUndo = false
    public private(set) var canRedo = false
    private var previewRecipe: EditRecipe?

    public func undo() {
        guard let previous = undoStack.popLast() else { return }
        let current = recipe
        suppressUndoCapture = true
        recipe = previous
        suppressUndoCapture = false
        redoStack.append(current)
        updateUndoAvailability()
    }

    public func redo() {
        guard let next = redoStack.popLast() else { return }
        let current = recipe
        suppressUndoCapture = true
        recipe = next
        suppressUndoCapture = false
        undoStack.append(current)
        updateUndoAvailability()
    }

    public func resetAdjustments() {
        // Keep crop / lensCorrection / source — clear everything else.
        var fresh = EditRecipe()
        fresh.source = recipe.source
        fresh.createdAt = recipe.createdAt
        fresh.rating = recipe.rating
        fresh.operations.crop = recipe.operations.crop
        fresh.operations.lensCorrection = recipe.operations.lensCorrection
        recipe = fresh
    }

    private func updateUndoAvailability() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
    }

    public func applyAutoAdjust(from stats: ImageStatistics) {
        let derived = AutoAdjust.operations(from: stats)
        var updated = recipe
        updated.operations.exposure = derived.exposure
        updated.operations.tone.contrast = derived.tone.contrast
        updated.operations.tone.highlightRecovery = derived.tone.highlightRecovery
        if derived.whiteBalance.mode == WhiteBalanceOp.custom {
            updated.operations.whiteBalance = derived.whiteBalance
        }
        recipe = updated
    }

    public func applyMatchedLook(reference refStats: ImageStatistics, intensity: Double) {
        guard let currentStats = statisticsForMatching() else { return }
        let derived = MatchLook.deriveOperations(
            from: refStats,
            current: currentStats,
            intensity: intensity
        )

        var updated = recipe
        updated.operations.exposure = derived.exposure
        updated.operations.tone.contrast = derived.tone.contrast
        updated.operations.tone.highlights = derived.tone.highlights
        updated.operations.tone.shadows = derived.tone.shadows
        updated.operations.tone.whites = derived.tone.whites
        updated.operations.tone.blacks = derived.tone.blacks
        updated.operations.tone.highlightRecovery = derived.tone.highlightRecovery
        updated.operations.toneCurve = derived.toneCurve
        updated.operations.color = derived.color
        updated.operations.hsl = derived.hsl
        updated.operations.colorGrading = derived.colorGrading
        if derived.whiteBalance.mode == WhiteBalanceOp.custom {
            updated.operations.whiteBalance = derived.whiteBalance
        }
        recipe = updated
    }

    public func preview(preset: Preset, amount: Double) {
        var preview = recipe
        preview.apply(preset: preset, amount: amount)
        previewRecipe = preview
        renderedImage = renderRecipe()
        scheduleHistogram()
    }

    public func preview(style: Style, amount: Double) {
        var preview = recipe
        preview.apply(style: style, amount: amount)
        previewRecipe = preview
        renderedImage = renderRecipe()
        scheduleHistogram()
    }

    public func cancelStylePreview() {
        guard previewRecipe != nil else { return }
        previewRecipe = nil
        renderedImage = renderRecipe()
        scheduleHistogram()
    }

    public func apply(preset: Preset, amount: Double) {
        cancelStylePreview()
        var updated = recipe
        updated.apply(preset: preset, amount: amount)
        recipe = updated
    }

    public func apply(style: Style, amount: Double) {
        cancelStylePreview()
        var updated = recipe
        updated.apply(style: style, amount: amount)
        recipe = updated
    }

    public func statisticsForMatching() -> ImageStatistics? {
        guard let image = sourceImageForAnalysis() else { return nil }
        return ImageStatisticsCalculator.compute(from: image)
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

    /// When set to a band index (0=red ... 7=magenta), the canvas
    /// desaturates everything outside that hue range so the user sees
    /// exactly which pixels an HSL adjustment will affect. View-only
    /// state — never persisted to the sidecar.
    public var previewIsolation: Int? {
        didSet {
            if previewIsolation != oldValue {
                renderedImage = renderRecipe()
            }
        }
    }

    /// True when the user is holding the before/after key, so the canvas
    /// shows the un-edited cached decode instead of the pipelined output.
    public var showBefore: Bool = false {
        didSet {
            if showBefore != oldValue {
                renderedImage = renderRecipe()
            }
        }
    }

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

    /// Width-over-height of the source image (post-decode, no crop). Used by
    /// the crop panel so aspect-ratio math accounts for the source's native
    /// aspect — picking "1:1" needs to produce a square crop, not a square
    /// rect of normalized coords.
    public var sourceAspectRatio: CGFloat {
        if let cached = cachedDecode.anyCached(for: source.url) {
            let ext = cached.extent
            if ext.width.isFinite, ext.height.isFinite, ext.width > 0, ext.height > 0 {
                return ext.width / ext.height
            }
        }
        if let w = exif?.pixelWidth, let h = exif?.pixelHeight, w > 0, h > 0 {
            return CGFloat(w) / CGFloat(h)
        }
        return 1.5 // 3:2 fallback
    }

    /// Rendered editing surface for the crop tool: all current photographic
    /// adjustments, but with crop disabled so the on-canvas handles can edit
    /// the real crop rectangle without the image jumping underneath them.
    public var cropCanvasImage: CIImage? {
        var cropRecipe = previewRecipe ?? recipe
        cropRecipe.operations.crop = CropOp(enabled: false)
        return renderRecipe(using: cropRecipe)
    }

    private func renderRecipe() -> CIImage? {
        let activeRecipe = previewRecipe ?? recipe
        return renderRecipe(using: activeRecipe)
    }

    private func renderRecipe(using activeRecipe: EditRecipe) -> CIImage? {
        let lensEnabled = activeRecipe.operations.lensCorrection.enabled
        // Prefer the matching variant; fall back to the other one while a
        // toggle re-decode is in flight so the canvas never blanks.
        let cached = cachedDecode.cached(for: source.url, applyLensCorrection: lensEnabled)
            ?? cachedDecode.anyCached(for: source.url)
        guard let cached else { return nil }
        if showBefore {
            return cached
        }
        var clamped = activeRecipe
        Clamping.clampInPlace(&clamped)
        var img = pipeline.apply(clamped, to: cached)
        if let bandIndex = previewIsolation {
            img = IsolationFilter().apply(image: img, bandIndex: bandIndex)
        }
        return img
    }

    private func sourceImageForAnalysis() -> CIImage? {
        let lensEnabled = recipe.operations.lensCorrection.enabled
        return cachedDecode.cached(for: source.url, applyLensCorrection: lensEnabled)
            ?? cachedDecode.anyCached(for: source.url)
            ?? renderedImage
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
