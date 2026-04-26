import Foundation
import CoreImage

/// CPU implementations of the noise primitives we feed to GrainFilter.
/// Two algorithms suffice for the Capture-One-style grain engine:
///
///   - Simplex — high-frequency gradient noise without directional
///     artifacts. Used for Fine and Silver Rich (low-persistence) and
///     for the multi-octave Silver Rich variant.
///   - Voronoi — F1 Worley cellular noise; the "platelet" cell shape
///     is what Cubic and Tabular use to evoke modern T-grain crystals.
///
/// Generated at a moderate resolution (default 1024²) and cached, then
/// Lanczos-upsampled to the image extent — fast enough that slider
/// drags don't burn 80ms per frame, and any tile alignment is
/// jittered per image via a hashed offset upstream.
public enum ProceduralNoise {
    public enum Algorithm: String, CaseIterable {
        case simplex
        case voronoi
    }

    public static let defaultDimension = 1024

    /// Returns a 4-channel RGBA-float CIImage of grayscale noise at
    /// `dimension × dimension`. Cached by all input parameters.
    public static func image(
        algorithm: Algorithm,
        dimension: Int = defaultDimension,
        scale: Float = 1.0,
        octaves: Int = 1,
        anisotropy: Float = 1.0,    // Voronoi only: aspect ratio of cells
        seed: UInt32 = 0
    ) -> CIImage? {
        let key = "\(algorithm.rawValue)-\(dimension)-\(scale)-\(octaves)-\(anisotropy)-\(seed)"
        if let cached = NoiseImageCache.shared.image(forKey: key) {
            return cached
        }
        let values = generate(
            algorithm: algorithm,
            dimension: dimension,
            scale: scale,
            octaves: octaves,
            anisotropy: anisotropy,
            seed: seed
        )
        var bytes = [Float](repeating: 0, count: dimension * dimension * 4)
        for i in 0..<values.count {
            bytes[i * 4 + 0] = values[i]
            bytes[i * 4 + 1] = values[i]
            bytes[i * 4 + 2] = values[i]
            bytes[i * 4 + 3] = 1
        }
        let data = bytes.withUnsafeBufferPointer { Data(buffer: $0) }
        let image: CIImage? = CIImage(
            bitmapData: data,
            bytesPerRow: dimension * MemoryLayout<Float>.size * 4,
            size: CGSize(width: dimension, height: dimension),
            format: .RGBAf,
            colorSpace: ColorSpaces.sRGB
        )
        if let image {
            NoiseImageCache.shared.set(image, forKey: key)
        }
        return image
    }

    public static func generate(
        algorithm: Algorithm,
        dimension: Int,
        scale: Float,
        octaves: Int,
        anisotropy: Float,
        seed: UInt32
    ) -> [Float] {
        switch algorithm {
        case .simplex:
            return simplexNoise(dimension: dimension, scale: scale,
                                octaves: octaves, seed: seed)
        case .voronoi:
            return voronoiNoise(dimension: dimension, scale: scale,
                                anisotropy: anisotropy, seed: seed)
        }
    }

    // MARK: - Simplex

    private static let F2: Float = 0.5 * (sqrt(3.0) - 1.0)
    private static let G2: Float = (3.0 - sqrt(3.0)) / 6.0

    private static func simplexNoise(dimension: Int, scale: Float, octaves: Int, seed: UInt32) -> [Float] {
        let perm = makePermutation(seed: seed == 0 ? 0x9876_5432 : seed)
        let actualOctaves = max(1, min(6, octaves))
        let baseFreq: Float = max(0.001, 8.0 * scale / Float(dimension))
        var out = [Float](repeating: 0, count: dimension * dimension)
        var amplitudeSum: Float = 0

        for octave in 0..<actualOctaves {
            let freq = baseFreq * pow(2.0, Float(octave))
            let amplitude: Float = pow(0.5, Float(octave))
            amplitudeSum += amplitude

            for y in 0..<dimension {
                for x in 0..<dimension {
                    let n = simplex2D(x: Float(x) * freq, y: Float(y) * freq, perm: perm)
                    out[y * dimension + x] += (n * 0.5 + 0.5) * amplitude
                }
            }
        }
        for i in 0..<out.count { out[i] /= amplitudeSum }
        return out
    }

    private static func simplex2D(x: Float, y: Float, perm: [Int]) -> Float {
        let s = (x + y) * F2
        let i = Int((x + s).rounded(.down))
        let j = Int((y + s).rounded(.down))
        let t = Float(i + j) * G2
        let x0 = x - (Float(i) - t)
        let y0 = y - (Float(j) - t)

        let i1: Int, j1: Int
        if x0 > y0 { i1 = 1; j1 = 0 } else { i1 = 0; j1 = 1 }

        let x1 = x0 - Float(i1) + G2
        let y1 = y0 - Float(j1) + G2
        let x2 = x0 - 1.0 + 2.0 * G2
        let y2 = y0 - 1.0 + 2.0 * G2

        let ii = i & 255
        let jj = j & 255
        let gi0 = perm[ii + perm[jj]] & 7
        let gi1 = perm[ii + i1 + perm[jj + j1]] & 7
        let gi2 = perm[ii + 1 + perm[jj + 1]] & 7

        var n0: Float = 0, n1: Float = 0, n2: Float = 0
        var t0 = 0.5 - x0 * x0 - y0 * y0
        if t0 > 0 { t0 *= t0; n0 = t0 * t0 * grad2(gi0, x0, y0) }
        var t1 = 0.5 - x1 * x1 - y1 * y1
        if t1 > 0 { t1 *= t1; n1 = t1 * t1 * grad2(gi1, x1, y1) }
        var t2 = 0.5 - x2 * x2 - y2 * y2
        if t2 > 0 { t2 *= t2; n2 = t2 * t2 * grad2(gi2, x2, y2) }
        return max(-1, min(1, 70 * (n0 + n1 + n2)))
    }

    private static func grad2(_ hash: Int, _ x: Float, _ y: Float) -> Float {
        let h = hash & 7
        let u = h < 4 ? x : y
        let v = h < 4 ? y : x
        return ((h & 1) != 0 ? -u : u) + ((h & 2) != 0 ? -v : v)
    }

    // MARK: - Voronoi (F1 Worley with anisotropic cells)

    /// `anisotropy = 1.0` → roughly circular cells (Cubic).
    /// `anisotropy > 1.0` → cells stretched horizontally (Tabular platelets).
    /// Distance is measured in stretched space so the F1 contour becomes
    /// elliptical instead of circular.
    private static func voronoiNoise(dimension: Int, scale: Float, anisotropy: Float, seed: UInt32) -> [Float] {
        let cellSize = max(8, Int(round(28 * scale)))
        let cellsPerSide = max(2, dimension / cellSize)
        let totalCells = cellsPerSide * cellsPerSide

        var rng = SeededRNG(seed: seed == 0 ? 0xF1F1_F1F1 : seed)
        var seeds = [(Float, Float)]()
        seeds.reserveCapacity(totalCells)
        for cy in 0..<cellsPerSide {
            for cx in 0..<cellsPerSide {
                let baseX = (Float(cx) + rng.nextUnitFloat()) * Float(cellSize)
                let baseY = (Float(cy) + rng.nextUnitFloat()) * Float(cellSize)
                seeds.append((baseX, baseY))
            }
        }

        let aspectX: Float = anisotropy
        let aspectY: Float = 1.0
        var out = [Float](repeating: 0, count: dimension * dimension)
        var maxDist: Float = 0

        for y in 0..<dimension {
            for x in 0..<dimension {
                let cx = min(cellsPerSide - 1, max(0, x / cellSize))
                let cy = min(cellsPerSide - 1, max(0, y / cellSize))
                var minSq: Float = .greatestFiniteMagnitude
                // Search a wider neighborhood in the stretched dimension
                // so anisotropic cells resolve correctly across boundaries.
                let dxRange = anisotropy > 1.5 ? 2 : 1
                for dy in -1...1 {
                    let ny = cy + dy
                    if ny < 0 || ny >= cellsPerSide { continue }
                    for dx in -dxRange...dxRange {
                        let nx = cx + dx
                        if nx < 0 || nx >= cellsPerSide { continue }
                        let s = seeds[ny * cellsPerSide + nx]
                        let ddx = (Float(x) - s.0) / aspectX
                        let ddy = (Float(y) - s.1) / aspectY
                        let d = ddx * ddx + ddy * ddy
                        if d < minSq { minSq = d }
                    }
                }
                let dist = sqrt(minSq)
                if dist > maxDist { maxDist = dist }
                out[y * dimension + x] = dist
            }
        }
        if maxDist > 0 {
            for i in 0..<out.count { out[i] /= maxDist }
        }
        return out
    }

    // MARK: - Helpers

    private static func makePermutation(seed: UInt32) -> [Int] {
        var rng = SeededRNG(seed: seed)
        var p = Array(0..<256)
        for i in stride(from: 255, through: 1, by: -1) {
            let j = Int(rng.next() % UInt32(i + 1))
            p.swapAt(i, j)
        }
        return p + p
    }
}

struct SeededRNG {
    private var state: UInt32

    init(seed: UInt32) {
        self.state = seed == 0 ? 0xDEAD_BEEF : seed
    }

    mutating func next() -> UInt32 {
        state = state &* 1_664_525 &+ 1_013_904_223
        return state
    }

    mutating func nextUnitFloat() -> Float {
        Float(next()) / Float(UInt32.max)
    }
}

final class NoiseImageCache: @unchecked Sendable {
    static let shared = NoiseImageCache()
    private var entries: [String: CIImage] = [:]
    private var order: [String] = []
    private let lock = NSLock()
    private let maxEntries = 16

    func image(forKey key: String) -> CIImage? {
        lock.lock()
        defer { lock.unlock() }
        return entries[key]
    }

    func set(_ image: CIImage, forKey key: String) {
        lock.lock()
        defer { lock.unlock() }
        if entries[key] == nil {
            order.append(key)
            if order.count > maxEntries {
                let evict = order.removeFirst()
                entries.removeValue(forKey: evict)
            }
        }
        entries[key] = image
    }
}
