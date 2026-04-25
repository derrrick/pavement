import Foundation
import CoreGraphics

/// Canonical CGColorSpaces used by the engine. Display P3 is the working space.
public enum ColorSpaces {
    public static let displayP3: CGColorSpace = CGColorSpace(name: CGColorSpace.displayP3)!
    public static let sRGB: CGColorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    public static let adobeRGB: CGColorSpace = CGColorSpace(name: CGColorSpace.adobeRGB1998)!
}
