import Foundation
import CoreImage

/// Crop in normalized coordinates (PLAN.md §5 schema: x/y/w/h on the
/// top-left-origin source image, in 0..1). Rotation is applied around the
/// crop rect's center so the rect itself stays fixed and the source pixels
/// rotate underneath it — mirrors how Lightroom's crop tool feels.
public struct CropFilter {
    public init() {}

    public func apply(image: CIImage, op: CropOp) -> CIImage {
        guard op.enabled else { return image }

        let extent = image.extent
        guard extent.width > 0, extent.height > 0,
              extent.width.isFinite, extent.height.isFinite else { return image }

        let cropRect = Self.cropRectInImage(extent: extent, op: op)
        guard cropRect.width > 0, cropRect.height > 0 else { return image }

        var img = image
        if op.rotation != 0 {
            let center = CGPoint(x: cropRect.midX, y: cropRect.midY)
            let radians = -CGFloat(op.rotation) * .pi / 180 // CW positive in PLAN.md
            let transform = CGAffineTransform.identity
                .translatedBy(x: center.x, y: center.y)
                .rotated(by: radians)
                .translatedBy(x: -center.x, y: -center.y)
            img = img.transformed(by: transform)
        }

        return img.cropped(to: cropRect)
    }

    /// PLAN.md uses top-left origin; CIImage uses bottom-left.
    /// recipeY=0 is the top of the image; ciY=extent.maxY is the top.
    public static func cropRectInImage(extent: CGRect, op: CropOp) -> CGRect {
        let w = CGFloat(op.w) * extent.width
        let h = CGFloat(op.h) * extent.height
        let x = extent.minX + CGFloat(op.x) * extent.width
        let y = extent.minY + (1 - CGFloat(op.y) - CGFloat(op.h)) * extent.height
        return CGRect(x: x, y: y, width: w, height: h)
    }

    /// Returns the closest aspect ratio the operator targets, or nil for free.
    public static func aspectRatio(_ aspect: String) -> CGFloat? {
        switch aspect {
        case "1:1":  return 1
        case "3:2":  return 3.0 / 2.0
        case "4:5":  return 4.0 / 5.0
        case "16:9": return 16.0 / 9.0
        default:     return nil
        }
    }
}
