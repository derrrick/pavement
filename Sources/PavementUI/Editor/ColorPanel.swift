import SwiftUI
import PavementCore

struct ColorPanel: View {
    @Bindable var document: PavementDocument

    private var isModified: Bool {
        !ColorAdjustFilter.isIdentity(document.recipe.operations.color)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HueSpectrumStrip(
                hueRotationDegrees: document.recipe.operations.color.hue,
                saturationBoost: document.recipe.operations.color.saturation,
                luminanceShift: document.recipe.operations.color.luminance
            )
            .frame(height: 18)

            slider(
                label: "Hue",
                keyPath: \.hue,
                range: -180...180,
                step: 1,
                format: "%+d°",
                defaultValue: 0
            )
            slider(
                label: "Saturation",
                keyPath: \.saturation,
                range: -100...100,
                step: 1,
                format: "%+d",
                defaultValue: 0
            )
            slider(
                label: "Vibrance",
                keyPath: \.vibrance,
                range: -100...100,
                step: 1,
                format: "%+d",
                defaultValue: 0
            )
            slider(
                label: "Luminance",
                keyPath: \.luminance,
                range: -100...100,
                step: 1,
                format: "%+d",
                defaultValue: 0
            )
        }
    }

    private func slider(
        label: String,
        keyPath: WritableKeyPath<ColorOp, Int>,
        range: ClosedRange<Int>,
        step: Int,
        format: String,
        defaultValue: Int
    ) -> some View {
        HStack {
            Text(label).font(.callout).frame(width: 86, alignment: .leading)
            Slider(
                value: Binding(
                    get: { Double(document.recipe.operations.color[keyPath: keyPath]) },
                    set: { document.recipe.operations.color[keyPath: keyPath] = Int($0.rounded()) }
                ),
                in: Double(range.lowerBound)...Double(range.upperBound),
                step: Double(step)
            )
            Text(String(format: format, document.recipe.operations.color[keyPath: keyPath]))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .trailing)
                .onTapGesture(count: 2) {
                    document.recipe.operations.color[keyPath: keyPath] = defaultValue
                }
                .help("Double-click to reset")
        }
    }
}

/// A 360° hue spectrum strip that previews the current global color
/// adjustment by rotating itself with `hueRotationDegrees`, scaling
/// saturation, and shifting luminance. Cheap visual feedback that
/// composes with whatever bands are tweaked in HSLPanel.
private struct HueSpectrumStrip: View {
    let hueRotationDegrees: Int
    let saturationBoost: Int
    let luminanceShift: Int

    var body: some View {
        Canvas { ctx, size in
            let bands = 60
            let satFactor = max(0, 1 + Double(saturationBoost) / 100.0)
            let lumOffset = Double(luminanceShift) / 200.0
            for i in 0..<bands {
                let x = CGFloat(i) / CGFloat(bands) * size.width
                let nextX = CGFloat(i + 1) / CGFloat(bands) * size.width
                var hueDeg = Double(i) * 360.0 / Double(bands) + Double(hueRotationDegrees)
                hueDeg = hueDeg.truncatingRemainder(dividingBy: 360)
                if hueDeg < 0 { hueDeg += 360 }
                let saturation = max(0, min(1, 0.85 * satFactor))
                let brightness = max(0.1, min(1, 0.92 + lumOffset))
                let color = Color(hue: hueDeg / 360, saturation: saturation, brightness: brightness)
                ctx.fill(
                    Path(CGRect(x: x, y: 0, width: nextX - x + 0.5, height: size.height)),
                    with: .color(color)
                )
            }

            // Subtle border
            let border = Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 4)
            ctx.stroke(border, with: .color(.white.opacity(0.15)), lineWidth: 0.5)
        }
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}
