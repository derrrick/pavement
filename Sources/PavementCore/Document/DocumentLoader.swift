import Foundation

public struct DocumentLoader {
    public init() {}

    /// Loads or creates a PavementDocument for `item`:
    /// 1. Reads EXIF and computes the source fingerprint.
    /// 2. Loads the existing JSON sidecar (running migrations + clamping)
    ///    or seeds a new recipe with the source metadata.
    /// 3. Primes the CachedDecode for the source URL so the first render
    ///    has a bitmap ready.
    @MainActor
    public func load(
        item: SourceItem,
        cachedDecode: CachedDecode
    ) async throws -> PavementDocument {
        let url = item.url

        async let fingerprintTask = Task.detached(priority: .userInitiated) { () throws -> String in
            try SourceFingerprint.compute(url: url)
        }.value
        let exif = ExifReader().read(url: url)

        let store = SidecarStore()
        var recipe: EditRecipe
        if let existing = try store.load(for: url) {
            recipe = existing
            try Migrations.upgrade(&recipe)
            Clamping.clampInPlace(&recipe)
        } else {
            recipe = EditRecipe()
            recipe.source.path = url.lastPathComponent
        }

        let fingerprint = try await fingerprintTask
        if recipe.source.fingerprint.isEmpty {
            recipe.source.fingerprint = fingerprint
        }
        cachedDecode.applyLensCorrection = recipe.operations.lensCorrection.enabled
        if let exif {
            if recipe.source.camera == nil { recipe.source.camera = exif.camera }
            if recipe.source.lens == nil { recipe.source.lens = exif.lens }
            if recipe.source.iso == nil { recipe.source.iso = exif.iso }
            if recipe.source.captureTime == nil { recipe.source.captureTime = exif.captureTime }
        }

        // Prime the cache off-main so the editor's first render has a bitmap.
        _ = try await Task.detached(priority: .userInitiated) { () -> Void in
            _ = try cachedDecode.image(for: url)
        }.value

        return PavementDocument(
            source: item,
            recipe: recipe,
            exif: exif,
            fingerprint: fingerprint,
            cachedDecode: cachedDecode
        )
    }
}
