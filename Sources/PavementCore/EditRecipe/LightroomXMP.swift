import Foundation

/// Parses Lightroom (.xmp / .lrtemplate) preset files into Pavement
/// styles. Maps the most common Adobe Camera RAW fields to our
/// operations schema. Complex structures (tone curve points, color
/// grading wheels) are best-effort: scalar attributes are mapped
/// directly; nested rdf:Seq tone-curves are parsed when present.
public enum LightroomXMP {
    public enum ParseError: Error, CustomStringConvertible {
        case noAttributes

        public var description: String {
            switch self {
            case .noAttributes: return "XMP file contained no recognizable Camera Raw fields"
            }
        }
    }

    public static func parse(_ xml: String, name: String) throws -> Style {
        let parser = XMPParser()
        parser.run(xml: xml)
        guard !parser.attributes.isEmpty else { throw ParseError.noAttributes }
        let ops = mapAttributes(parser.attributes, toneCurve: parser.toneCurvePoints)
        return Style(
            name: name,
            category: "Lightroom",
            description: "Imported from Lightroom XMP",
            operations: ops
        )
    }

    /// Map known Camera Raw / Lightroom keys (without the `crs:` prefix)
    /// to recipe operations. Unknown keys are dropped silently.
    static func mapAttributes(_ attrs: [String: String], toneCurve: [[Double]]) -> Operations {
        var ops = Operations()

        // Exposure (-5..+5 stops)
        if let v = parseDouble(attrs["Exposure2012"] ?? attrs["Exposure"]) {
            ops.exposure.ev = clamp(v, -5, 5)
        }

        // Tone (-100..100)
        if let v = parseInt(attrs["Contrast2012"] ?? attrs["Contrast"])   { ops.tone.contrast = clamp(v, -100, 100) }
        if let v = parseInt(attrs["Highlights2012"] ?? attrs["Highlights"]) { ops.tone.highlights = clamp(v, -100, 100) }
        if let v = parseInt(attrs["Shadows2012"] ?? attrs["Shadows"])     { ops.tone.shadows = clamp(v, -100, 100) }
        if let v = parseInt(attrs["Whites2012"] ?? attrs["Whites"])       { ops.tone.whites = clamp(v, -100, 100) }
        if let v = parseInt(attrs["Blacks2012"] ?? attrs["Blacks"])       { ops.tone.blacks = clamp(v, -100, 100) }

        // Color: vibrance / saturation
        if let v = parseInt(attrs["Vibrance"])   { ops.color.vibrance = clamp(v, -100, 100) }
        if let v = parseInt(attrs["Saturation"]) { ops.color.saturation = clamp(v, -100, 100) }

        // White balance (Lightroom encodes Temperature in Kelvin already
        // for "Custom" presets; "As Shot" presets omit it)
        if let v = parseInt(attrs["Temperature"]), v > 0 {
            ops.whiteBalance.mode = WhiteBalanceOp.custom
            ops.whiteBalance.temp = clamp(v, 2000, 50000)
        }
        if let v = parseInt(attrs["Tint"]) {
            ops.whiteBalance.tint = clamp(v, -150, 150)
        }

        // HSL bands (Lightroom uses 8 bands matching ours)
        for (lrBand, kp) in hslMap {
            if let h = parseInt(attrs["HueAdjustment\(lrBand)"]) {
                writeHSL(&ops.hsl, kp, .h, value: clamp(h, -100, 100))
            }
            if let s = parseInt(attrs["SaturationAdjustment\(lrBand)"]) {
                writeHSL(&ops.hsl, kp, .s, value: clamp(s, -100, 100))
            }
            if let l = parseInt(attrs["LuminanceAdjustment\(lrBand)"]) {
                writeHSL(&ops.hsl, kp, .l, value: clamp(l, -100, 100))
            }
        }

        // Split toning (older Lightroom; pre-Color Grading)
        if let h = parseInt(attrs["SplitToningShadowHue"]) {
            ops.colorGrading.shadows.hue = clamp(h, 0, 360)
        }
        if let s = parseInt(attrs["SplitToningShadowSaturation"]) {
            ops.colorGrading.shadows.sat = clamp(s, -100, 100)
        }
        if let h = parseInt(attrs["SplitToningHighlightHue"]) {
            ops.colorGrading.highlights.hue = clamp(h, 0, 360)
        }
        if let s = parseInt(attrs["SplitToningHighlightSaturation"]) {
            ops.colorGrading.highlights.sat = clamp(s, -100, 100)
        }
        if let b = parseInt(attrs["SplitToningBalance"]) {
            ops.colorGrading.balance = clamp(b, -100, 100)
        }

        // Color Grading (newer Lightroom; CG fields override split toning when present)
        if let h = parseInt(attrs["ColorGradeShadowHue"]) {
            ops.colorGrading.shadows.hue = clamp(h, 0, 360)
        }
        if let s = parseInt(attrs["ColorGradeShadowSat"]) {
            ops.colorGrading.shadows.sat = clamp(s, -100, 100)
        }
        if let h = parseInt(attrs["ColorGradeHighlightHue"]) {
            ops.colorGrading.highlights.hue = clamp(h, 0, 360)
        }
        if let s = parseInt(attrs["ColorGradeHighlightSat"]) {
            ops.colorGrading.highlights.sat = clamp(s, -100, 100)
        }
        if let h = parseInt(attrs["ColorGradeMidtoneHue"]) {
            ops.colorGrading.midtones.hue = clamp(h, 0, 360)
        }
        if let s = parseInt(attrs["ColorGradeMidtoneSat"]) {
            ops.colorGrading.midtones.sat = clamp(s, -100, 100)
        }
        if let h = parseInt(attrs["ColorGradeGlobalHue"]) {
            ops.colorGrading.global.hue = clamp(h, 0, 360)
        }
        if let s = parseInt(attrs["ColorGradeGlobalSat"]) {
            ops.colorGrading.global.sat = clamp(s, -100, 100)
        }
        if let b = parseInt(attrs["ColorGradeBlending"]) {
            ops.colorGrading.blending = clamp(b, 0, 100)
        }

        // Detail (Lightroom uses 0..150 sharpening, 0..100 noise)
        if let v = parseInt(attrs["Sharpness"])             { ops.detail.sharpAmount = clamp(v, 0, 150) }
        if let v = parseDouble(attrs["SharpenRadius"])      { ops.detail.sharpRadius = clamp(v, 0.5, 3.0) }
        if let v = parseInt(attrs["SharpenDetail"])         { /* mapped to masking */ ops.detail.sharpMasking = clamp(v, 0, 100) }
        if let v = parseInt(attrs["LuminanceSmoothing"])    { ops.detail.noiseLuma = clamp(v, 0, 100) }
        if let v = parseInt(attrs["ColorNoiseReduction"])   { ops.detail.noiseColor = clamp(v, 0, 100) }

        // Grain
        if let v = parseInt(attrs["GrainAmount"])    { ops.grain.amount = clamp(v, 0, 100) }
        if let v = parseInt(attrs["GrainSize"])      { ops.grain.size = clamp(v, 0, 100) }
        if let v = parseInt(attrs["GrainFrequency"]) { ops.grain.roughness = clamp(v, 0, 100) }

        // Vignette
        if let v = parseInt(attrs["PostCropVignetteAmount"])    { ops.vignette.amount = clamp(v, -100, 100) }
        if let v = parseInt(attrs["PostCropVignetteMidpoint"])  { ops.vignette.midpoint = clamp(v, 0, 100) }
        if let v = parseInt(attrs["PostCropVignetteFeather"])   { ops.vignette.feather = clamp(v, 0, 100) }
        if let v = parseInt(attrs["PostCropVignetteRoundness"]) { ops.vignette.roundness = clamp(v, -100, 100) }

        // B&W
        if let v = attrs["ConvertToGrayscale"], v.lowercased() == "true" {
            ops.bw.enabled = true
        }

        // Tone curve points (0..255 in source) → normalized [[x, y]]
        if !toneCurve.isEmpty {
            ops.toneCurve.rgb = toneCurve
        }

        return ops
    }

    private static let hslMap: [(String, BandKey)] = [
        ("Red", .red), ("Orange", .orange), ("Yellow", .yellow),
        ("Green", .green), ("Aqua", .aqua), ("Blue", .blue),
        ("Purple", .purple), ("Magenta", .magenta)
    ]

    private enum BandKey { case red, orange, yellow, green, aqua, blue, purple, magenta }
    private enum HSLAxis { case h, s, l }

    private static func writeHSL(_ hsl: inout HSLOp, _ band: BandKey, _ axis: HSLAxis, value: Int) {
        switch (band, axis) {
        case (.red, .h):     hsl.red.h = value
        case (.red, .s):     hsl.red.s = value
        case (.red, .l):     hsl.red.l = value
        case (.orange, .h):  hsl.orange.h = value
        case (.orange, .s):  hsl.orange.s = value
        case (.orange, .l):  hsl.orange.l = value
        case (.yellow, .h):  hsl.yellow.h = value
        case (.yellow, .s):  hsl.yellow.s = value
        case (.yellow, .l):  hsl.yellow.l = value
        case (.green, .h):   hsl.green.h = value
        case (.green, .s):   hsl.green.s = value
        case (.green, .l):   hsl.green.l = value
        case (.aqua, .h):    hsl.aqua.h = value
        case (.aqua, .s):    hsl.aqua.s = value
        case (.aqua, .l):    hsl.aqua.l = value
        case (.blue, .h):    hsl.blue.h = value
        case (.blue, .s):    hsl.blue.s = value
        case (.blue, .l):    hsl.blue.l = value
        case (.purple, .h):  hsl.purple.h = value
        case (.purple, .s):  hsl.purple.s = value
        case (.purple, .l):  hsl.purple.l = value
        case (.magenta, .h): hsl.magenta.h = value
        case (.magenta, .s): hsl.magenta.s = value
        case (.magenta, .l): hsl.magenta.l = value
        }
    }

    private static func parseDouble(_ s: String?) -> Double? {
        guard let s else { return nil }
        let trimmed = s.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "+", with: "")
        return Double(trimmed)
    }

    private static func parseInt(_ s: String?) -> Int? {
        guard let d = parseDouble(s) else { return nil }
        return Int(d.rounded())
    }

    private static func clamp<T: Comparable>(_ v: T, _ lo: T, _ hi: T) -> T {
        min(max(v, lo), hi)
    }
}

private final class XMPParser: NSObject, XMLParserDelegate {
    var attributes: [String: String] = [:]
    var toneCurvePoints: [[Double]] = []

    private var inToneCurve = false
    private var currentLi: String?

    func run(xml: String) {
        guard let data = xml.data(using: .utf8) else { return }
        let parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = false
        parser.delegate = self
        parser.parse()
    }

    func parser(_ parser: XMLParser,
                didStartElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?,
                attributes attributeDict: [String: String]) {
        // Description holds the bulk of attribute-style fields
        if elementName.lowercased().hasSuffix(":description")
            || elementName.lowercased() == "rdf:description"
            || elementName.lowercased() == "description" {
            for (key, value) in attributeDict {
                if let cleaned = stripPrefix(key) {
                    attributes[cleaned] = value
                }
            }
        }
        if elementName.lowercased() == "crs:tonecurvepv2012"
            || elementName.lowercased() == "crs:tonecurvepv2012red"
            || elementName.lowercased() == "crs:tonecurve" {
            inToneCurve = true
            toneCurvePoints.removeAll()
        }
        if elementName.lowercased() == "rdf:li" && inToneCurve {
            currentLi = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if currentLi != nil {
            currentLi! += string
        }
    }

    func parser(_ parser: XMLParser,
                didEndElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?) {
        if elementName.lowercased() == "rdf:li", let li = currentLi {
            let parts = li.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 2, let x = Double(parts[0]), let y = Double(parts[1]) {
                toneCurvePoints.append([x / 255.0, y / 255.0])
            }
            currentLi = nil
        }
        if elementName.lowercased().hasPrefix("crs:tonecurve") {
            inToneCurve = false
        }
    }

    /// Strip "crs:" / "lr:" namespace prefixes; return nil for non-Adobe attrs.
    private func stripPrefix(_ key: String) -> String? {
        if key.hasPrefix("crs:") { return String(key.dropFirst(4)) }
        if key.hasPrefix("lr:")  { return String(key.dropFirst(3)) }
        return nil
    }
}
