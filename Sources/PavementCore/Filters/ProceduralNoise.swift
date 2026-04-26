import Foundation
import CoreImage

/// CPU implementations of the canonical noise algorithms used by
/// GrainFilter. We generate at moderate resolution (768²) and let
/// CILanczosScaleTransform up-sample to the image extent — the eye
/// can't see per-pixel grain at typical viewing scales, and the
/// CPU cost stays under ~30ms per algorithm at this size.
public enum ProceduralNoise {
    public enum Algorithm: String, CaseIterable {
        case uniform        // per-pixel random in [0, 1]
        case gaussian       // per-pixel bell-curve distribution
        case value          // random values per grid cell, smoothly interpolated
        case perlin         // classic Perlin gradient noise
        case simplex        // simplex (Stefan Gustavson) — no directional artifacts
        case voronoi        // F1 Worley cellular noise (silver-halide structure)
    }

    public static let defaultDimension = 768

    /// Generate a 4-channel RGBA-float CIImage of noise. Grayscale
    /// (R = G = B = noise value), alpha 1. The image is at
    /// `dimension × dimension`; callers upscale to the source extent.
    public static func image(
        algorithm: Algorithm,
        dimension: Int = defaultDimension,
        scale: Float = 1.0,
        octaves: Int = 1,
        seed: UInt32 = 0
    ) -> CIImage? {
        let cacheKey = "\(algorithm.rawValue)-\(dimension)-\(scale)-\(octaves)-\(seed)"
        if let cached = NoiseImageCache.shared.image(forKey: cacheKey) {
            return cached
        }
        let values = generate(
            algorithm: algorithm,
            dimension: dimension,
            scale: scale,
            octaves: octaves,
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
            NoiseImageCache.shared.set(image, forKey: cacheKey)
        }
        return image
    }

    /// Returns a flat [width*height] array of noise values in [0, 1].
    public static func generate(
        algorithm: Algorithm,
        dimension: Int,
        scale: Float,
        octaves: Int,
        seed: UInt32
    ) -> [Float] {
        switch algorithm {
        case .uniform:  return uniformNoise(dimension: dimension, seed: seed)
        case .gaussian: return gaussianNoise(dimension: dimension, seed: seed)
        case .value:    return valueNoise(dimension: dimension, scale: scale, octaves: octaves, seed: seed)
        case .perlin:   return perlinNoise(dimension: dimension, scale: scale, octaves: octaves, seed: seed)
        case .simplex:  return simplexNoise(dimension: dimension, scale: scale, octaves: octaves, seed: seed)
        case .voronoi:  return voronoiNoise(dimension: dimension, scale: scale, seed: seed)
        }
    }

    // MARK: - Uniform

    private static func uniformNoise(dimension: Int, seed: UInt32) -> [Float] {
        var rng = SeededRNG(seed: seed == 0 ? 0xDEAD_BEEF : seed)
        var out = [Float](repeating: 0, count: dimension * dimension)
        for i in 0..<out.count {
            out[i] = rng.nextUnitFloat()
        }
        return out
    }

    // MARK: - Gaussian

    private static func gaussianNoise(dimension: Int, seed: UInt32) -> [Float] {
        var rng = SeededRNG(seed: seed == 0 ? 0xCAFE_F00D : seed)
        var out = [Float](repeating: 0, count: dimension * dimension)
        var i = 0
        while i < out.count {
            // Box-Muller produces TWO gaussian samples per call.
            let u1 = max(.leastNormalMagnitude, rng.nextUnitFloat())
            let u2 = rng.nextUnitFloat()
            let mag = sqrt(-2 * log(u1))
            let z0 = mag * cos(2 * .pi * u2)
            let z1 = mag * sin(2 * .pi * u2)
            // Map z (mean 0, stddev 1) to roughly [0, 1] via z * 0.18 + 0.5
            // (clamped). Most samples land in [0.1, 0.9].
            out[i] = max(0, min(1, z0 * 0.18 + 0.5))
            if i + 1 < out.count {
                out[i + 1] = max(0, min(1, z1 * 0.18 + 0.5))
            }
            i += 2
        }
        return out
    }

    // MARK: - Value noise

    private static func valueNoise(dimension: Int, scale: Float, octaves: Int, seed: UInt32) -> [Float] {
        // Cell size in pixels — larger scale = larger cells.
        let baseCellSize = max(2, Int(round(8 * scale)))
        let actualOctaves = max(1, min(6, octaves))
        var out = [Float](repeating: 0, count: dimension * dimension)
        var amplitudeSum: Float = 0

        for octave in 0..<actualOctaves {
            let cellSize = max(2, baseCellSize / (1 << octave))
            let amplitude: Float = pow(0.5, Float(octave))
            amplitudeSum += amplitude

            // Pre-compute random values at each grid corner
            let gridW = dimension / cellSize + 2
            let gridH = dimension / cellSize + 2
            var grid = [Float](repeating: 0, count: gridW * gridH)
            var rng = SeededRNG(seed: seed == 0 ? 0x12345 : seed &+ UInt32(octave) &* 0x9E37)
            for i in 0..<grid.count { grid[i] = rng.nextUnitFloat() }

            for y in 0..<dimension {
                for x in 0..<dimension {
                    let xc = Float(x) / Float(cellSize)
                    let yc = Float(y) / Float(cellSize)
                    let xi = Int(xc)
                    let yi = Int(yc)
                    let xf = xc - Float(xi)
                    let yf = yc - Float(yi)
                    let v00 = grid[yi * gridW + xi]
                    let v10 = grid[yi * gridW + xi + 1]
                    let v01 = grid[(yi + 1) * gridW + xi]
                    let v11 = grid[(yi + 1) * gridW + xi + 1]
                    let u = smoothstep(xf)
                    let v = smoothstep(yf)
                    let value = lerp(lerp(v00, v10, u), lerp(v01, v11, u), v)
                    out[y * dimension + x] += value * amplitude
                }
            }
        }
        // Normalize back to [0, 1]
        for i in 0..<out.count { out[i] /= amplitudeSum }
        return out
    }

    // MARK: - Perlin noise

    private static func perlinNoise(dimension: Int, scale: Float, octaves: Int, seed: UInt32) -> [Float] {
        let perm = makePermutation(seed: seed == 0 ? 0xABCD_1234 : seed)
        let actualOctaves = max(1, min(6, octaves))
        let baseFreq: Float = max(0.001, 4.0 * scale / Float(dimension))
        var out = [Float](repeating: 0, count: dimension * dimension)
        var amplitudeSum: Float = 0

        for octave in 0..<actualOctaves {
            let freq = baseFreq * pow(2.0, Float(octave))
            let amplitude: Float = pow(0.5, Float(octave))
            amplitudeSum += amplitude

            for y in 0..<dimension {
                for x in 0..<dimension {
                    let n = perlin2D(
                        x: Float(x) * freq,
                        y: Float(y) * freq,
                        perm: perm
                    )
                    // perlin2D returns [-1, 1]; map to [0, 1]
                    out[y * dimension + x] += (n * 0.5 + 0.5) * amplitude
                }
            }
        }
        for i in 0..<out.count { out[i] /= amplitudeSum }
        return out
    }

    private static func perlin2D(x: Float, y: Float, perm: [Int]) -> Float {
        let xi = Int(x.rounded(.down)) & 255
        let yi = Int(y.rounded(.down)) & 255
        let xf = x - x.rounded(.down)
        let yf = y - y.rounded(.down)
        let u = fade(xf)
        let v = fade(yf)
        let a  = perm[xi] + yi
        let b  = perm[xi + 1] + yi
        let aa = perm[a]
        let ab = perm[a + 1]
        let ba = perm[b]
        let bb = perm[b + 1]
        let x1 = lerp(grad2(aa, xf, yf),       grad2(ba, xf - 1, yf),       u)
        let x2 = lerp(grad2(ab, xf, yf - 1),   grad2(bb, xf - 1, yf - 1),   u)
        // Output is in roughly [-0.7, 0.7]; clamp + map to [-1, 1].
        return max(-1, min(1, lerp(x1, x2, v) * 1.4))
    }

    private static func grad2(_ hash: Int, _ x: Float, _ y: Float) -> Float {
        // Ken Perlin's classic 2D gradient — picks one of 8 unit vectors
        // via the low 3 bits of the hash. Output magnitude stays bounded
        // so downstream lerp/fade keeps Perlin in roughly [-1, 1].
        let h = hash & 7
        let u = h < 4 ? x : y
        let v = h < 4 ? y : x
        return ((h & 1) != 0 ? -u : u) + ((h & 2) != 0 ? -v : v)
    }

    // MARK: - Simplex noise

    private static let F2: Float = 0.5 * (sqrt(3.0) - 1.0)
    private static let G2: Float = (3.0 - sqrt(3.0)) / 6.0

    private static func simplexNoise(dimension: Int, scale: Float, octaves: Int, seed: UInt32) -> [Float] {
        let perm = makePermutation(seed: seed == 0 ? 0x9876_5432 : seed)
        let actualOctaves = max(1, min(6, octaves))
        let baseFreq: Float = max(0.001, 4.0 * scale / Float(dimension))
        var out = [Float](repeating: 0, count: dimension * dimension)
        var amplitudeSum: Float = 0

        for octave in 0..<actualOctaves {
            let freq = baseFreq * pow(2.0, Float(octave))
            let amplitude: Float = pow(0.5, Float(octave))
            amplitudeSum += amplitude

            for y in 0..<dimension {
                for x in 0..<dimension {
                    let n = simplex2D(
                        x: Float(x) * freq,
                        y: Float(y) * freq,
                        perm: perm
                    )
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

        let i1: Int
        let j1: Int
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
        if t0 > 0 {
            t0 *= t0
            n0 = t0 * t0 * grad2(gi0, x0, y0)
        }
        var t1 = 0.5 - x1 * x1 - y1 * y1
        if t1 > 0 {
            t1 *= t1
            n1 = t1 * t1 * grad2(gi1, x1, y1)
        }
        var t2 = 0.5 - x2 * x2 - y2 * y2
        if t2 > 0 {
            t2 *= t2
            n2 = t2 * t2 * grad2(gi2, x2, y2)
        }
        // Standard Simplex 2D scale factor lands the output in roughly
        // [-1, 1]; clamp to be safe against edge cases.
        return max(-1, min(1, 70 * (n0 + n1 + n2)))
    }

    // MARK: - Voronoi (F1 Worley cellular noise)

    private static func voronoiNoise(dimension: Int, scale: Float, seed: UInt32) -> [Float] {
        // Pick number of seed cells based on scale: small scale = many
        // small cells, large scale = fewer big ones.
        let cellSize = max(8, Int(round(28 * scale)))
        let cellsPerSide = max(2, dimension / cellSize)
        let totalCells = cellsPerSide * cellsPerSide

        // Place one random point per cell-grid square (jittered grid).
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

        var out = [Float](repeating: 0, count: dimension * dimension)
        var maxDist: Float = 0

        // Spatial-grid nearest-neighbor lookup: for each pixel only check
        // seeds in the surrounding 3×3 cell neighborhood.
        for y in 0..<dimension {
            for x in 0..<dimension {
                let cx = min(cellsPerSide - 1, max(0, x / cellSize))
                let cy = min(cellsPerSide - 1, max(0, y / cellSize))
                var minSq: Float = .greatestFiniteMagnitude
                for dy in -1...1 {
                    let ny = cy + dy
                    if ny < 0 || ny >= cellsPerSide { continue }
                    for dx in -1...1 {
                        let nx = cx + dx
                        if nx < 0 || nx >= cellsPerSide { continue }
                        let seed = seeds[ny * cellsPerSide + nx]
                        let ddx = Float(x) - seed.0
                        let ddy = Float(y) - seed.1
                        let d = ddx * ddx + ddy * ddy
                        if d < minSq { minSq = d }
                    }
                }
                let dist = sqrt(minSq)
                if dist > maxDist { maxDist = dist }
                out[y * dimension + x] = dist
            }
        }
        // Normalize to [0, 1]
        if maxDist > 0 {
            for i in 0..<out.count { out[i] /= maxDist }
        }
        return out
    }

    // MARK: - Helpers

    private static func makePermutation(seed: UInt32) -> [Int] {
        var rng = SeededRNG(seed: seed)
        var p = Array(0..<256)
        // Fisher-Yates shuffle with seeded RNG
        for i in stride(from: 255, through: 1, by: -1) {
            let j = Int(rng.next() % UInt32(i + 1))
            p.swapAt(i, j)
        }
        return p + p
    }

    @inline(__always)
    private static func fade(_ t: Float) -> Float {
        t * t * t * (t * (t * 6 - 15) + 10)
    }

    @inline(__always)
    private static func smoothstep(_ t: Float) -> Float {
        t * t * (3 - 2 * t)
    }

    @inline(__always)
    private static func lerp(_ a: Float, _ b: Float, _ t: Float) -> Float {
        a + t * (b - a)
    }
}

/// Linear-congruential RNG with explicit seed. Same seed → same sequence
/// across runs, so the cached noise textures are deterministic.
struct SeededRNG {
    private var state: UInt32

    init(seed: UInt32) {
        self.state = seed == 0 ? 0xDEAD_BEEF : seed
    }

    mutating func next() -> UInt32 {
        // Numerical Recipes LCG constants
        state = state &* 1_664_525 &+ 1_013_904_223
        return state
    }

    mutating func nextUnitFloat() -> Float {
        Float(next()) / Float(UInt32.max)
    }
}

/// Cache of generated noise images keyed by parameters. CPU generation
/// of Perlin/Voronoi at 768² is ~30-80ms — cached so slider drags on
/// `amount` (which doesn't affect the noise pattern) reuse the texture
/// instead of regenerating per frame. Modest size limit; LRU-ish.
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
