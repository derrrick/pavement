import Foundation
import CoreImage

/// Caches the post-decode CIImage per (source URL, lens-correction flag)
/// so toggling lens correction doesn't invalidate the existing decode —
/// both variants stay cached and the next render picks the matching one.
public final class CachedDecode {
    public typealias Provider = (URL) throws -> CIImage

    private struct Key: Hashable {
        let url: URL
        let lensCorrected: Bool
    }

    private var cache: [Key: CIImage] = [:]
    private let lock = NSLock()
    private let providerOverride: Provider?

    public init(provider: Provider? = nil) {
        self.providerOverride = provider
    }

    public func image(for url: URL, applyLensCorrection: Bool = true) throws -> CIImage {
        let key = Key(url: url, lensCorrected: applyLensCorrection)
        lock.lock()
        if let cached = cache[key] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let image: CIImage
        if let providerOverride {
            image = try providerOverride(url)
        } else {
            image = try Self.realize(url: url, applyLensCorrection: applyLensCorrection)
        }

        lock.lock()
        if let raced = cache[key] {
            lock.unlock()
            return raced
        }
        cache[key] = image
        lock.unlock()
        return image
    }

    public func cached(for url: URL, applyLensCorrection: Bool = true) -> CIImage? {
        let key = Key(url: url, lensCorrected: applyLensCorrection)
        lock.lock()
        defer { lock.unlock() }
        return cache[key]
    }

    /// Returns any cached entry for `url` regardless of the lens flag.
    /// Used as a fallback by the editor while a fresh decode is in flight,
    /// so the canvas keeps showing the last good image instead of blanking.
    public func anyCached(for url: URL) -> CIImage? {
        lock.lock()
        defer { lock.unlock() }
        return cache.first(where: { $0.key.url == url })?.value
    }

    public func invalidate(_ url: URL) {
        lock.lock()
        cache = cache.filter { $0.key.url != url }
        lock.unlock()
    }

    public func clear() {
        lock.lock()
        cache.removeAll()
        lock.unlock()
    }

    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return cache.count
    }

    /// Decode + realize to a half-float P3 bitmap so subsequent renders
    /// skip the demosaic.
    public static func realize(url: URL, applyLensCorrection: Bool) throws -> CIImage {
        let decoded = try DecodeStage().decode(url: url, applyLensCorrection: applyLensCorrection)
        let ctx = PipelineContext.shared.context
        let extent = decoded.extent
        guard extent.width.isFinite, extent.height.isFinite,
              extent.width > 0, extent.height > 0 else { return decoded }
        if let cg = ctx.createCGImage(
            decoded,
            from: extent,
            format: .RGBAh,
            colorSpace: ColorSpaces.displayP3
        ) {
            return CIImage(cgImage: cg)
        }
        return decoded
    }
}
