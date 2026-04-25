import Foundation
import CoreGraphics

public enum ExportFormat: String, Codable, CaseIterable {
    case jpeg
    case tiff
}

public enum ExportColorSpaceTag: String, Codable, CaseIterable {
    case sRGB
    case displayP3
    case adobeRGB

    public var cgColorSpace: CGColorSpace {
        switch self {
        case .sRGB:      return ColorSpaces.sRGB
        case .displayP3: return ColorSpaces.displayP3
        case .adobeRGB:  return ColorSpaces.adobeRGB
        }
    }
}

public enum SharpeningStrength: String, Codable, CaseIterable {
    case none
    case screen
    case print

    public var amount: Float {
        switch self {
        case .none:   return 0
        case .screen: return 0.4
        case .print:  return 0.7
        }
    }

    public var radius: Float {
        switch self {
        case .none:   return 0
        case .screen: return 1.0
        case .print:  return 1.5
        }
    }
}

public struct ExportSpec: Equatable {
    public let name: String
    public let format: ExportFormat
    public let longEdge: Int?      // nil = no resize
    public let colorSpace: ExportColorSpaceTag
    public let quality: Float      // 0..1, JPEG only
    public let bitDepth: Int       // 8 or 16
    public let sharpening: SharpeningStrength
    public let folderName: String  // subfolder under _exports/

    public init(
        name: String,
        format: ExportFormat,
        longEdge: Int?,
        colorSpace: ExportColorSpaceTag,
        quality: Float,
        bitDepth: Int,
        sharpening: SharpeningStrength,
        folderName: String
    ) {
        self.name = name
        self.format = format
        self.longEdge = longEdge
        self.colorSpace = colorSpace
        self.quality = quality
        self.bitDepth = bitDepth
        self.sharpening = sharpening
        self.folderName = folderName
    }
}

public enum ExportPreset: String, CaseIterable, Identifiable {
    case instagram
    case web
    case print

    public var id: String { rawValue }

    public var spec: ExportSpec {
        switch self {
        case .instagram:
            return ExportSpec(
                name: "Instagram",
                format: .jpeg,
                longEdge: 1350,
                colorSpace: .sRGB,
                quality: 0.9,
                bitDepth: 8,
                sharpening: .screen,
                folderName: "instagram"
            )
        case .web:
            return ExportSpec(
                name: "Web",
                format: .jpeg,
                longEdge: 2048,
                colorSpace: .sRGB,
                quality: 0.8,
                bitDepth: 8,
                sharpening: .screen,
                folderName: "web"
            )
        case .print:
            return ExportSpec(
                name: "Print",
                format: .tiff,
                longEdge: nil,
                colorSpace: .displayP3,
                quality: 1.0,
                bitDepth: 16,
                sharpening: .print,
                folderName: "print"
            )
        }
    }

    public var displayName: String { spec.name }
}
