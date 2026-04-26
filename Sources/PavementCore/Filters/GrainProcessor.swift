import Foundation
import CoreImage
import Metal

/// Bridges the `grainKernel` Metal compute shader into the CIImage
/// pipeline via `CIImageProcessorKernel`. Each render allocates one
/// transient output texture and dispatches the kernel — no persistent
/// state, no bitmap buffers.
///
/// Parameters mirror the shader's `GrainParams` struct, sent as raw
/// bytes over `setBytes`. `seed` is hashed up the chain in
/// `GrainFilter` so the noise stays stable across slider drags but
/// changes per-image.
final class GrainProcessor: CIImageProcessorKernel {

    /// Mirrors GrainParams in GrainKernel.metal — keep field order in sync.
    ///
    /// `originX/Y` and `extentScaleX/Y` are populated per-dispatch inside
    /// `process(...)` from `output.region` and the destination texture
    /// dimensions. Together they let the kernel translate its tile-local
    /// `gid` into ABSOLUTE IMAGE-EXTENT coordinates regardless of how CI
    /// tiled or fused downstream transforms:
    ///
    ///     pos_extent = (originX, originY) + gid * (extentScaleX, extentScaleY)
    ///
    /// When CI hasn't fused (texture matches region 1:1), extentScale = 1
    /// and pos_extent = origin + gid. When CI has fused a downstream
    /// canvas scale (e.g. drawable is 1500×1000 but kernel's extent rect
    /// is 6000×4000), texture is smaller than region and extentScale = 4
    /// — gid steps still cover 1 extent unit each, so the noise grid
    /// stays welded to image pixels and zooms with them.
    struct Params {
        var amount: Float
        var granularity: Float
        var roughness: Float
        var falloff: Float
        var type: Int32
        var seed: UInt32
        var originX: Float
        var originY: Float
        var extentScaleX: Float
        var extentScaleY: Float
    }

    /// Lazy pipeline state. Compiles the kernel once at first use, caches
    /// forever. We ship `GrainKernel.metal` as a raw resource (not pre-
    /// compiled) and call `device.makeLibrary(source:)` at runtime —
    /// keeps the build portable and avoids the Metal Toolchain Xcode
    /// component requirement.
    private static let pipeline: MTLComputePipelineState? = {
        guard let device = PipelineContext.shared.device else {
            Log.pipeline.warning("GrainProcessor: no Metal device available")
            return nil
        }
        guard let url = Bundle.module.url(forResource: "GrainKernel", withExtension: "msl") else {
            Log.pipeline.warning("GrainProcessor: GrainKernel.msl not found in bundle")
            return nil
        }
        guard let source = try? String(contentsOf: url, encoding: .utf8) else {
            Log.pipeline.warning("GrainProcessor: could not read GrainKernel.metal")
            return nil
        }
        let options = MTLCompileOptions()
        options.languageVersion = .version3_0
        let library: MTLLibrary
        do {
            library = try device.makeLibrary(source: source, options: options)
        } catch {
            Log.pipeline.error("GrainProcessor compile failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
        guard let function = library.makeFunction(name: "grainKernel") else {
            Log.pipeline.warning("GrainProcessor: grainKernel function missing from library")
            return nil
        }
        return try? device.makeComputePipelineState(function: function)
    }()

    static func apply(image: CIImage, params: Params) -> CIImage {
        guard pipeline != nil else { return image }
        let extent = image.extent
        guard extent.width.isFinite, extent.height.isFinite,
              extent.width > 0, extent.height > 0 else { return image }
        do {
            return try GrainProcessor.apply(
                withExtent: extent,
                inputs: [image],
                arguments: ["params": params]
            )
        } catch {
            Log.pipeline.warning("GrainProcessor.apply failed: \(error.localizedDescription, privacy: .public)")
            return image
        }
    }

    // MARK: - CIImageProcessorKernel overrides

    override class var outputFormat: CIFormat { .RGBAh }
    override class var synchronizeInputs: Bool { false }

    override class func roi(forInput input: Int32, arguments: [String : Any]?, outputRect: CGRect) -> CGRect {
        // Each output pixel reads exactly one input pixel + computes its
        // own noise from coordinates — no spatial dependency, no halo.
        return outputRect
    }

    override class func process(
        with inputs: [CIImageProcessorInput]?,
        arguments: [String : Any]?,
        output: CIImageProcessorOutput
    ) throws {
        guard let pipeline = pipeline else {
            throw NSError(domain: "GrainProcessor", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "No Metal pipeline"])
        }
        guard let input = inputs?.first,
              let inTex = input.metalTexture,
              let outTex = output.metalTexture,
              let buffer = output.metalCommandBuffer,
              var params = arguments?["params"] as? Params else {
            throw NSError(domain: "GrainProcessor", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Missing inputs / outputs"])
        }
        guard let encoder = buffer.makeComputeCommandEncoder() else {
            throw NSError(domain: "GrainProcessor", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: "Could not create encoder"])
        }
        // Stamp this dispatch's extent rect AND the texture-to-extent
        // ratio into the params. CI may give us a destination texture
        // that is SMALLER than `output.region` when it has fused a
        // downstream scale (e.g. canvas zoom-out). In that case one
        // texture pixel covers >1 extent unit, so the kernel must scale
        // gid steps by `region.size / texture.size` to keep the noise
        // grid measured in IMAGE-EXTENT units. That's what makes the
        // grain stay welded to image pixels when the user zooms.
        let regionWidth  = Float(output.region.width)
        let regionHeight = Float(output.region.height)
        let texW = Float(max(1, outTex.width))
        let texH = Float(max(1, outTex.height))
        params.originX = Float(output.region.minX)
        params.originY = Float(output.region.minY)
        params.extentScaleX = regionWidth / texW
        params.extentScaleY = regionHeight / texH

        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(inTex,  index: 0)
        encoder.setTexture(outTex, index: 1)
        encoder.setBytes(&params, length: MemoryLayout<Params>.stride, index: 0)

        let tg = MTLSize(width: 16, height: 16, depth: 1)
        let groups = MTLSize(
            width:  (outTex.width  + tg.width  - 1) / tg.width,
            height: (outTex.height + tg.height - 1) / tg.height,
            depth: 1
        )
        encoder.dispatchThreadgroups(groups, threadsPerThreadgroup: tg)
        encoder.endEncoding()
    }
}
