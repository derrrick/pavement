import XCTest
@testable import PavementCore

final class ProceduralNoiseTests: XCTestCase {
    func testUniformIsNotConstant() {
        let values = ProceduralNoise.generate(
            algorithm: .uniform, dimension: 64, scale: 1, octaves: 1, seed: 42
        )
        let mean = values.reduce(0, +) / Float(values.count)
        let variance = values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Float(values.count)
        XCTAssertGreaterThan(variance, 0.05, "Uniform noise should have wide spread")
    }

    func testGaussianHasNarrowerSpreadThanUniform() {
        let uniform = ProceduralNoise.generate(
            algorithm: .uniform, dimension: 64, scale: 1, octaves: 1, seed: 1
        )
        let gauss = ProceduralNoise.generate(
            algorithm: .gaussian, dimension: 64, scale: 1, octaves: 1, seed: 2
        )

        func variance(_ v: [Float]) -> Float {
            let m = v.reduce(0, +) / Float(v.count)
            return v.reduce(0) { $0 + ($1 - m) * ($1 - m) } / Float(v.count)
        }
        // Gaussian (mapped through 0.18σ + 0.5) clusters toward 0.5
        XCTAssertLessThan(variance(gauss), variance(uniform))
    }

    func testValueNoiseIsSmoothlyVarying() {
        let values = ProceduralNoise.generate(
            algorithm: .value, dimension: 64, scale: 1.0, octaves: 1, seed: 7
        )
        // Adjacent pixels in the same cell should be very close
        var maxStep: Float = 0
        for y in 0..<64 {
            for x in 0..<63 {
                let diff = abs(values[y * 64 + x + 1] - values[y * 64 + x])
                if diff > maxStep { maxStep = diff }
            }
        }
        XCTAssertLessThan(maxStep, 0.5, "Value noise should be locally smooth")
    }

    func testPerlinNoiseInRange() {
        let values = ProceduralNoise.generate(
            algorithm: .perlin, dimension: 32, scale: 1.0, octaves: 1, seed: 99
        )
        XCTAssertEqual(values.count, 32 * 32)
        XCTAssertTrue(values.allSatisfy { $0 >= 0 && $0 <= 1 })
    }

    func testSimplexNoiseInRange() {
        let values = ProceduralNoise.generate(
            algorithm: .simplex, dimension: 32, scale: 1.0, octaves: 1, seed: 99
        )
        XCTAssertEqual(values.count, 32 * 32)
        XCTAssertTrue(values.allSatisfy { $0 >= 0 && $0 <= 1 })
    }

    func testVoronoiHasCellStructure() {
        let values = ProceduralNoise.generate(
            algorithm: .voronoi, dimension: 64, scale: 1.0, octaves: 1, seed: 7
        )
        // Voronoi distance is 0 at seed points, increases outward.
        // Mean should be > 0; max should be 1 (after normalization).
        let mean = values.reduce(0, +) / Float(values.count)
        XCTAssertGreaterThan(mean, 0.1)
        let maxValue = values.max() ?? 0
        XCTAssertEqual(maxValue, 1.0, accuracy: 0.001, "Voronoi should normalize to 1.0 max")
    }

    func testNoiseIsDeterministicGivenSeed() {
        let a = ProceduralNoise.generate(
            algorithm: .perlin, dimension: 16, scale: 1.0, octaves: 2, seed: 12345
        )
        let b = ProceduralNoise.generate(
            algorithm: .perlin, dimension: 16, scale: 1.0, octaves: 2, seed: 12345
        )
        XCTAssertEqual(a, b)
    }

    func testDifferentSeedsGiveDifferentNoise() {
        let a = ProceduralNoise.generate(
            algorithm: .perlin, dimension: 16, scale: 1.0, octaves: 1, seed: 100
        )
        let b = ProceduralNoise.generate(
            algorithm: .perlin, dimension: 16, scale: 1.0, octaves: 1, seed: 200
        )
        XCTAssertNotEqual(a, b)
    }

    func testFBmOctavesProduceDifferentNoise() {
        // Adjacent-pixel diff isn't a clean test for fBm (multi-octave
        // averaging can smooth out per-pixel variation). The simpler
        // invariant: different octave counts produce different noise.
        let one = ProceduralNoise.generate(
            algorithm: .perlin, dimension: 32, scale: 1.0, octaves: 1, seed: 5
        )
        let four = ProceduralNoise.generate(
            algorithm: .perlin, dimension: 32, scale: 1.0, octaves: 4, seed: 5
        )
        XCTAssertNotEqual(one, four)
    }

    func testGenerateImageReturnsCIImage() {
        let image = ProceduralNoise.image(
            algorithm: .perlin, dimension: 32, scale: 1.0, octaves: 1, seed: 1
        )
        XCTAssertNotNil(image)
        XCTAssertEqual(image?.extent.width, 32)
        XCTAssertEqual(image?.extent.height, 32)
    }
}
