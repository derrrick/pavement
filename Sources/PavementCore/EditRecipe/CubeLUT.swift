import Foundation

/// Adobe .cube 3D LUT parser. Format spec: a header with LUT_3D_SIZE N
/// declaring the cube dimension, optional DOMAIN_MIN/MAX, then N³ rows
/// of "r g b" floats in [0, 1] (typically). Comments start with #.
///
/// We read into the same RGBA-float layout the rest of the engine uses
/// (CIColorCube-compatible: R fastest, then G, then B).
public enum CubeLUT {
    public enum ParseError: Error, CustomStringConvertible {
        case missingDimension
        case incompleteData(expected: Int, got: Int)
        case unsupportedDimension(Int)

        public var description: String {
            switch self {
            case .missingDimension:
                return "LUT_3D_SIZE not declared in cube file"
            case .incompleteData(let expected, let got):
                return "Cube file declared \(expected) entries but contained \(got)"
            case .unsupportedDimension(let n):
                return "Cube dimension \(n) is outside the supported range (8…64)"
            }
        }
    }

    public static func parse(_ source: String, name: String) throws -> LUTData {
        var dimension = 0
        var domainMin = (r: Float(0), g: Float(0), b: Float(0))
        var domainMax = (r: Float(1), g: Float(1), b: Float(1))
        var entries: [(Float, Float, Float)] = []

        for rawLine in source.split(whereSeparator: { $0.isNewline }) {
            let line = rawLine.split(separator: "#").first.map(String.init) ?? ""
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            let parts = trimmed.split(whereSeparator: { $0.isWhitespace }).map(String.init)
            guard let head = parts.first else { continue }

            switch head.uppercased() {
            case "LUT_3D_SIZE":
                if parts.count >= 2, let n = Int(parts[1]) {
                    dimension = n
                }
            case "DOMAIN_MIN":
                if parts.count >= 4 {
                    domainMin = (Float(parts[1]) ?? 0, Float(parts[2]) ?? 0, Float(parts[3]) ?? 0)
                }
            case "DOMAIN_MAX":
                if parts.count >= 4 {
                    domainMax = (Float(parts[1]) ?? 1, Float(parts[2]) ?? 1, Float(parts[3]) ?? 1)
                }
            case "TITLE", "LUT_1D_SIZE":
                continue
            default:
                if parts.count >= 3,
                   let r = Float(parts[0]), let g = Float(parts[1]), let b = Float(parts[2]) {
                    entries.append((r, g, b))
                }
            }
        }

        guard dimension > 0 else { throw ParseError.missingDimension }
        guard dimension >= 8, dimension <= 64 else {
            throw ParseError.unsupportedDimension(dimension)
        }
        let expected = dimension * dimension * dimension
        guard entries.count == expected else {
            throw ParseError.incompleteData(expected: expected, got: entries.count)
        }

        // Renormalize from declared domain to 0..1.
        let rRange = max(0.0001, domainMax.r - domainMin.r)
        let gRange = max(0.0001, domainMax.g - domainMin.g)
        let bRange = max(0.0001, domainMax.b - domainMin.b)

        var bytes = [Float](repeating: 0, count: expected * 4)
        for (i, entry) in entries.enumerated() {
            // Cube file order: r changes fastest, then g, then b — same
            // as CIColorCube's expected layout.
            let r = (entry.0 - domainMin.r) / rRange
            let g = (entry.1 - domainMin.g) / gRange
            let b = (entry.2 - domainMin.b) / bRange
            let idx = i * 4
            bytes[idx + 0] = max(0, min(1, r))
            bytes[idx + 1] = max(0, min(1, g))
            bytes[idx + 2] = max(0, min(1, b))
            bytes[idx + 3] = 1
        }

        let data = bytes.withUnsafeBufferPointer { Data(buffer: $0) }
        return LUTData(dimension: dimension, data: data, name: name)
    }
}
