import SwiftUI
import PavementCore

public struct HistogramView: View {
    let histogram: Histogram

    public init(histogram: Histogram) {
        self.histogram = histogram
    }

    public var body: some View {
        Canvas { ctx, size in
            ctx.fill(
                Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 4),
                with: .color(Color(white: 0.06))
            )

            let max = max(1, CGFloat(histogram.maxRGB))
            let binWidth = size.width / 256
            let bins = histogram.red.count

            // Render each channel as an outlined area chart with additive
            // opacity so overlap looks white-ish (matching most editors).
            drawChannel(
                ctx: ctx, size: size, binWidth: binWidth,
                values: histogram.red, max: max,
                color: .red.opacity(0.55)
            )
            drawChannel(
                ctx: ctx, size: size, binWidth: binWidth,
                values: histogram.green, max: max,
                color: .green.opacity(0.55)
            )
            drawChannel(
                ctx: ctx, size: size, binWidth: binWidth,
                values: histogram.blue, max: max,
                color: .blue.opacity(0.55)
            )

            // Mid-grid lines at 0.25/0.5/0.75
            var grid = Path()
            for stop in [0.25, 0.5, 0.75] {
                let x = CGFloat(stop) * size.width
                grid.move(to: CGPoint(x: x, y: 0))
                grid.addLine(to: CGPoint(x: x, y: size.height))
            }
            ctx.stroke(grid, with: .color(.white.opacity(0.08)), lineWidth: 1)

            _ = bins
        }
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
}
