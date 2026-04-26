import SwiftUI
import PavementCore

public struct HistogramView: View {
    let histogram: Histogram

    public init(histogram: Histogram) {
        self.histogram = histogram
    }

    public var body: some View {
        VStack(spacing: 7) {
            header
            histogramCanvas
            footer
        }
        .padding(10)
        .background(
            LinearGradient(
                colors: [Theme.surfaceRaised.opacity(0.92), Theme.surfaceInset.opacity(0.92)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.09), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 12, y: 5)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Label("Histogram", systemImage: "waveform.path.ecg")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            clippingIndicator(label: "S", count: shadowClipCount)
            clippingIndicator(label: "H", count: highlightClipCount)
        }
    }

    private var histogramCanvas: some View {
        Canvas { ctx, size in
            let rect = CGRect(origin: .zero, size: size)
            ctx.fill(Path(roundedRect: rect, cornerRadius: 4), with: .color(Color.black.opacity(0.22)))

            let rampRect = CGRect(x: 0, y: size.height - 8, width: size.width, height: 8)
            ctx.fill(
                Path(rampRect),
                with: .linearGradient(
                    Gradient(colors: [.black, Color(white: 0.20), Color(white: 0.52), .white]),
                    startPoint: CGPoint(x: 0, y: rampRect.midY),
                    endPoint: CGPoint(x: size.width, y: rampRect.midY)
                )
            )

            let maxValue = max(1, CGFloat(max(histogram.maxRGB, histogram.luminance.max() ?? 0)))
            let binWidth = size.width / 256

            drawGrid(ctx: ctx, size: size)
            drawChannel(ctx: ctx, size: size, binWidth: binWidth, values: histogram.luminance, max: maxValue, color: .white.opacity(0.20))
            drawChannel(ctx: ctx, size: size, binWidth: binWidth, values: histogram.red, max: maxValue, color: .red.opacity(0.46))
            drawChannel(ctx: ctx, size: size, binWidth: binWidth, values: histogram.green, max: maxValue, color: .green.opacity(0.42))
            drawChannel(ctx: ctx, size: size, binWidth: binWidth, values: histogram.blue, max: maxValue, color: .blue.opacity(0.48))
        }
        .frame(height: 62)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var footer: some View {
        HStack {
            Text("Shadows")
            Spacer()
            Text("Midtones")
            Spacer()
            Text("Highlights")
        }
        .font(.caption2.monospacedDigit())
        .foregroundStyle(.tertiary)
    }

    private func drawChannel(
        ctx: GraphicsContext,
        size: CGSize,
        binWidth: CGFloat,
        values: [Int],
        max: CGFloat,
        color: Color
    ) {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: size.height))
        for i in 0..<values.count {
            let x = CGFloat(i) * binWidth
            let h = size.height * CGFloat(values[i]) / max
            path.addLine(to: CGPoint(x: x, y: size.height - h))
        }
        path.addLine(to: CGPoint(x: size.width, y: size.height))
        path.closeSubpath()
        ctx.fill(path, with: .color(color))
    }

    private func drawGrid(ctx: GraphicsContext, size: CGSize) {
        var grid = Path()
        for stop in [0.25, 0.5, 0.75] {
            let x = CGFloat(stop) * size.width
            grid.move(to: CGPoint(x: x, y: 0))
            grid.addLine(to: CGPoint(x: x, y: size.height))
        }
        for stop in [0.33, 0.66] {
            let y = CGFloat(stop) * size.height
            grid.move(to: CGPoint(x: 0, y: y))
            grid.addLine(to: CGPoint(x: size.width, y: y))
        }
        ctx.stroke(grid, with: .color(.white.opacity(0.07)), lineWidth: 1)
    }

    private func clippingIndicator(label: String, count: Int) -> some View {
        Text(label)
            .font(.caption2.monospacedDigit().weight(.bold))
            .foregroundStyle(count > 0 ? Color.orange : Color.secondary.opacity(0.75))
            .frame(width: 18, height: 16)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(count > 0 ? Color.orange.opacity(0.14) : Color.white.opacity(0.05))
            )
            .help(count > 0 ? "\(label == "S" ? "Shadow" : "Highlight") clipping detected" : "No \(label == "S" ? "shadow" : "highlight") clipping")
    }

    private var shadowClipCount: Int {
        histogram.red.prefix(2).reduce(0, +)
            + histogram.green.prefix(2).reduce(0, +)
            + histogram.blue.prefix(2).reduce(0, +)
    }

    private var highlightClipCount: Int {
        histogram.red.suffix(2).reduce(0, +)
            + histogram.green.suffix(2).reduce(0, +)
            + histogram.blue.suffix(2).reduce(0, +)
    }
}
