import Foundation
import CoreImage
import Metal

public final class PipelineContext {
    public static let shared = PipelineContext()

    public let device: MTLDevice?
    public let context: CIContext

    public init() {
        let device = MTLCreateSystemDefaultDevice()
        self.device = device

        var options: [CIContextOption: Any] = [
            .workingColorSpace: ColorSpaces.displayP3,
            .outputColorSpace:  ColorSpaces.displayP3,
            .cacheIntermediates: false,
            .useSoftwareRenderer: false,
        ]

        if let device {
            self.context = CIContext(mtlDevice: device, options: options)
            Log.pipeline.info("PipelineContext using Metal device \(device.name, privacy: .public)")
        } else {
            // Headless / SSH fallback (Phase 0-3 risk #6).
            options[.useSoftwareRenderer] = true
            self.context = CIContext(options: options)
            Log.pipeline.warning("PipelineContext: no Metal device, using software renderer")
        }
    }
}
