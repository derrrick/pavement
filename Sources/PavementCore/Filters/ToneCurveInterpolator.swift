import Foundation

public enum ToneCurveInterpolator {
    /// Catmull-Rom interpolation through `controlPoints` (each `[x, y]`) into
    /// `samples` evenly-spaced y values, where x = i / (samples - 1).
    /// The y values are clamped to 0...1; control point x is clamped + sorted
    /// + deduplicated. Endpoints are virtually extended via reflection so
    /// the curve passes naturally through P0 and Pn-1.
    public static func sample(controlPoints: [[Double]], samples: Int = 1024) -> [Float] {
        precondition(samples >= 2, "Need at least 2 samples")

        let cleaned = clean(controlPoints)
        if cleaned.count == 0 {
            return identity(samples: samples)
        }
        if cleaned.count == 1 {
            return [Float](repeating: Float(cleaned[0].y), count: samples)
        }

        // Phantom endpoints via reflection (Catmull-Rom open).
        let first = cleaned.first!
        let second = cleaned[1]
        let last = cleaned.last!
        let secondLast = cleaned[cleaned.count - 2]
        let pre = Point(x: first.x - (second.x - first.x), y: 2 * first.y - second.y)
        let post = Point(x: last.x + (last.x - secondLast.x), y: 2 * last.y - secondLast.y)
        let pts = [pre] + cleaned + [post]

        var result = [Float](repeating: 0, count: samples)
        var segmentIndex = 1 // start with [pts[1], pts[2]] segment

        for i in 0..<samples {
            let x = Double(i) / Double(samples - 1)

            while segmentIndex < pts.count - 2, pts[segmentIndex + 1].x < x {
                segmentIndex += 1
            }

            let p0 = pts[segmentIndex - 1]
            let p1 = pts[segmentIndex]
            let p2 = pts[segmentIndex + 1]
            let p3 = pts[segmentIndex + 2]

            let segLen = p2.x - p1.x
            let t = segLen <= 0 ? 0 : (x - p1.x) / segLen

            let y = catmullRomY(t: t, p0: p0.y, p1: p1.y, p2: p2.y, p3: p3.y)
            result[i] = Float(min(1, max(0, y)))
        }
        return result
    }

    // MARK: - Helpers

    private struct Point {
        var x: Double
        var y: Double
    }

    private static func clean(_ raw: [[Double]]) -> [Point] {
        var pts: [Point] = []
        for entry in raw where entry.count >= 2 {
            let x = min(1, max(0, entry[0]))
            let y = min(1, max(0, entry[1]))
            pts.append(Point(x: x, y: y))
        }
        pts.sort { $0.x < $1.x }
        // Drop duplicates with the same x; keep the first occurrence.
        var dedup: [Point] = []
        for p in pts {
            if dedup.last?.x != p.x {
                dedup.append(p)
            }
        }
        return dedup
    }

    private static func identity(samples: Int) -> [Float] {
        let denom = Float(samples - 1)
        return (0..<samples).map { Float($0) / denom }
    }

    @inline(__always)
    private static func catmullRomY(t: Double, p0: Double, p1: Double, p2: Double, p3: Double) -> Double {
        let t2 = t * t
        let t3 = t2 * t
        return 0.5 * (
            (2 * p1) +
            (-p0 + p2) * t +
            (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 +
            (-p0 + 3 * p1 - 3 * p2 + p3) * t3
        )
    }
}
