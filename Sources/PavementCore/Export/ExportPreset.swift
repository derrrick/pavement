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
    case instagramStory = "instagram-story"
    case web
    case webRetina = "web-retina"
    case fullJPEG = "full-jpeg"
    case fullJPEGP3 = "full-jpeg-p3"
    case fourK = "4k"
    case print
    case printLarge = "print-large"

    public var id: String { rawValue }

    public var spec: ExportSpec {
        switch self {
        case .instagram:
            // 1080×1350 portrait crop is IG's "best fit" for tall street
            // photos. sRGB JPEG q=0.9 is what IG re-encodes least.
            return ExportSpec(
                name: "Instagram (Portrait)",
                format: .jpeg,
                longEdge: 1350,
                colorSpace: .sRGB,
                quality: 0.9,
                bitDepth: 8,
                sharpening: .screen,
                folderName: "instagram"
            )
        case .instagramStory:
            // 1080×1920 — full-screen vertical for Stories / Reels.
            return ExportSpec(
                name: "Instagram Story (Vertical)",
                format: .jpeg,
                longEdge: 1920,
                colorSpace: .sRGB,
                quality: 0.9,
                bitDepth: 8,
                sharpening: .screen,
                folderName: "instagram-story"
            )
        case .web:
            return ExportSpec(
                name: "Web (2048px)",
                format: .jpeg,
                longEdge: 2048,
                colorSpace: .sRGB,
                quality: 0.85,
                bitDepth: 8,
                sharpening: .screen,
                folderName: "web"
            )
        case .webRetina:
            // 4096px wide — sharp at 2× retina display sizes.
            return ExportSpec(
                name: "Web Retina (4096px)",
                format: .jpeg,
                longEdge: 4096,
                colorSpace: .sRGB,
                quality: 0.85,
                bitDepth: 8,
                sharpening: .screen,
                folderName: "web-retina"
            )
        case .fourK:
            // 3840px long edge — for 4K monitors / TV slideshows.
            return ExportSpec(
                name: "4K Display",
                format: .jpeg,
                longEdge: 3840,
                colorSpace: .displayP3,
                quality: 0.92,
                bitDepth: 8,
                sharpening: .screen,
                folderName: "4k"
            )
        case .fullJPEG:
            // Full resolution, sRGB. Safe for any consumer pipeline.
            return ExportSpec(
                name: "Full Resolution JPEG (sRGB)",
                format: .jpeg,
                longEdge: nil,
                colorSpace: .sRGB,
                quality: 0.95,
                bitDepth: 8,
                sharpening: .none,
                folderName: "full-jpeg"
            )
        case .fullJPEGP3:
            // Full resolution, Display P3. Wide-gamut JPEG for modern
            // displays — Macs, recent iPhones, P3-capable monitors.
            return ExportSpec(
                name: "Full Resolution JPEG (P3)",
                format: .jpeg,
                longEdge: nil,
                colorSpace: .displayP3,
                quality: 0.95,
                bitDepth: 8,
                sharpening: .none,
                folderName: "full-jpeg-p3"
            )
        case .print:
            // 16-bit P3 TIFF, full resolution, print sharpening.
            return ExportSpec(
                name: "Print (16-bit TIFF, P3)",
                format: .tiff,
                longEdge: nil,
                colorSpace: .displayP3,
                quality: 1.0,
                bitDepth: 16,
                sharpening: .print,
                folderName: "print"
            )
        case .printLarge:
            // Same as Print but Adobe RGB — broader CMYK gamut for some
            // commercial labs that prefer it over P3.
            return ExportSpec(
                name: "Print Large (16-bit TIFF, AdobeRGB)",
                format: .tiff,
                longEdge: nil,
                colorSpace: .adobeRGB,
                quality: 1.0,
                bitDepth: 16,
                sharpening: .print,
                folderName: "print-large"
            )
        }
    }

    public var displayName: String { spec.name }
}
