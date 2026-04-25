import Foundation
import CoreImage

/// Caches the post-decode CIImage per source URL. The default provider
/// realizes the decoded image to a half-float bitmap in working color space
/// so subsequent renders skip the demosaic — a slider drag then only re-runs
/// the downstream filter chain.
public final class CachedDecode {
    public typealias Provider = (URL) throws -> CIImage

    private var cache: [URL: CIImage] = [:]
    private let lock = NSLock()
    private let provider: Provider

    public init(provider: @escaping Provider = CachedDecode.realizingProvider) {
        self.provider = provider
    }

    /// Default provider: decode + realize to half-float P3 bitmap.
    public static let realizingProvider: Provider = { url in
        let decoded = try DecodeStage().decode(url: url)
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

    public func image(for url: URL) throws -> CIImage {
        lock.lock()
        if let cached = cache[url] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let image = try provider(url)

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
}
