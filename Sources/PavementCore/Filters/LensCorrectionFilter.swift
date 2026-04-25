import Foundation
import CoreImage

/// Lens correction in Pavement v1 happens entirely inside CIRAWFilter at
/// decode time, gated by the recipe's `lensCorrection.enabled` flag (see
/// CachedDecode + DecodeStage). This pipeline step is a no-op placeholder
/// so the §4 ordering stays explicit; future custom strengths or Lensfun
/// integration land here without disturbing surrounding stages.
public struct LensCorrectionFilter {
    public init() {}

    public func apply(image: CIImage, op: LensCorrectionOp) -> CIImage {
        image
    }
}
