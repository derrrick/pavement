import Foundation
import CoreImage

/// Caches the post-decode CIImage per source URL. Calls into DecodeStage and
/// realizes the result to a half-float P3 bitmap so subsequent renders skip
/// the demosaic — slider drags re-run only the downstream filter chain.
public final class CachedDecode {
    public typealias Provider = (URL) throws -> CIImage

    private var cache: [URL: CIImage] = [:]
    private let lock = NSLock()
    private let providerOverride: Provider?

    /// Mirrors the recipe's lensCorrection.enabled. Setting this to a new
    /// value invalidates every cached image so the next decode re-runs
    /// CIRAWFilter with the updated toggle.
    public var applyLensCorrection: Bool = true {
        didSet { if oldValue != applyLensCorrection { clear() } }
    }

    public init(provider: Provider? = nil) {
        self.providerOverride = provider
    }

    public func image(for url: URL) throws -> CIImage {
        lock.lock()
        if let cached = cache[url] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let image = try resolve(url: url)

        lock.lock()
        if let raced = cache[url] {
            lock.unlock()
            return raced
        }
        cache[url] = image
        lock.unlock()
        return image
    }

    public func cached(for url: URL) -> CIImage? {
        lock.lock()
        defer { lock.unlock() }
        return cache[url]
    }

    public func invalidate(_ url: URL) {
        lock.lock()
        cache.removeValue(forKey: url)
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

    // MARK: - Provider

    private func resolve(url: URL) throws -> CIImage {
        if let providerOverride {
            return try providerOverride(url)
        }
        return try Self.realize(url: url, applyLensCorrection: applyLensCorrection)
    }

    /// Default decode path: CIRAWFilter (or CIImage(contentsOf:) for JPEGs)
    /// followed by a render to a half-float P3 bitmap.
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
