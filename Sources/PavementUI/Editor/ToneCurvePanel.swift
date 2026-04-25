import SwiftUI
import PavementCore

struct ToneCurvePanel: View {
    @Bindable var document: PavementDocument

    @State private var draggingIndex: Int?
    private static let hitRadius: CGFloat = 10
    private static let curveHeight: CGFloat = 240

    private var points: [[Double]] { document.recipe.operations.toneCurve.rgb }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Tone Curve").font(.headline)
                Spacer()
                Menu("Preset") {
                    Button("Identity") { setCurve([[0, 0], [1, 1]]) }
                    Button("Subtle S") { setCurve([[0, 0], [0.25, 0.18], [0.75, 0.82], [1, 1]]) }
                    Button("Heavy S") { setCurve([[0, 0], [0.25, 0.10], [0.75, 0.90], [1, 1]]) }
                    Button("Lift Shadows") { setCurve([[0, 0.05], [0.5, 0.55], [1, 1]]) }
                    Button("Crush Blacks") { setCurve([[0, 0], [0.15, 0.0], [1, 1]]) }
                }
                .menuStyle(.borderlessButton)
                .font(.caption)
                Button("Reset") { setCurve([[0, 0], [1, 1]]) }
                    .buttonStyle(.borderless)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                let size = CGSize(width: geo.size.width, height: Self.curveHeight)
                ZStack {
                    Canvas { ctx, sz in
                        drawBackground(ctx: ctx, size: sz)
                        drawGrid(ctx: ctx, size: sz)
                        drawDiagonal(ctx: ctx, size: sz)
                        drawCurve(ctx: ctx, size: sz)
                        drawControlPoints(ctx: ctx, size: sz)
                    }
                }
                .frame(width: size.width, height: size.height)
                .contentShape(Rectangle())
                .gesture(dragGesture(in: size))
            }
            .frame(height: Self.curveHeight)

            Text("Drag handles to shape the curve. Click empty space to add a point. Endpoints stay pinned at x = 0 and x = 1.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Drawing

    private func drawBackground(ctx: GraphicsContext, size: CGSize) {
        let rect = Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 4)
        ctx.fill(rect, with: .color(Color(white: 0.10)))
    }

    private func drawGrid(ctx: GraphicsContext, size: CGSize) {
        var path = Path()
        for i in 1..<4 {
            let t = CGFloat(i) / 4
            path.move(to: CGPoint(x: t * size.width, y: 0))
            path.addLine(to: CGPoint(x: t * size.width, y: size.height))
            path.move(to: CGPoint(x: 0, y: t * size.height))
            path.addLine(to: CGPoint(x: size.width, y: t * size.height))
        }
        ctx.stroke(path, with: .color(.white.opacity(0.08)), lineWidth: 1)
    }

    private func drawDiagonal(ctx: GraphicsContext, size: CGSize) {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: size.height))
        path.addLine(to: CGPoint(x: size.width, y: 0))
        ctx.stroke(path, with: .color(.white.opacity(0.18)), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
    }

    private func drawCurve(ctx: GraphicsContext, size: CGSize) {
        let samples = ToneCurveInterpolator.sample(controlPoints: points, samples: Int(size.width))
        guard samples.count >= 2 else { return }
        var path = Path()
        for i in 0..<samples.count {
            let cp = CGPoint(
                x: CGFloat(i) / CGFloat(samples.count - 1) * size.width,
                y: (1 - CGFloat(samples[i])) * size.height
            )
            if i == 0 { path.move(to: cp) } else { path.addLine(to: cp) }
        }
        ctx.stroke(path, with: .color(.white), lineWidth: 1.5)
    }

    private func drawControlPoints(ctx: GraphicsContext, size: CGSize) {
        for (index, pt) in points.enumerated() {
            let cp = canvasPoint(from: pt, in: size)
            let isDragging = (draggingIndex == index)
            let radius: CGFloat = isDragging ? 6 : 4
            let dot = Path(ellipseIn: CGRect(
                x: cp.x - radius, y: cp.y - radius,
                width: radius * 2, height: radius * 2
            ))
            ctx.fill(dot, with: .color(isDragging ? .accentColor : .white))
            ctx.stroke(dot, with: .color(.gray.opacity(0.6)), lineWidth: 1)
        }
    }

    // MARK: - Gesture

    private func dragGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                if draggingIndex == nil {
                    if let nearest = hitTest(value.startLocation, in: size) {
                        draggingIndex = nearest
                    } else {
                        let newPoint = imagePoint(from: value.startLocation, in: size)
                        addPoint(newPoint)
                    }
                }
                guard let idx = draggingIndex else { return }
                updatePoint(at: idx, to: value.location, in: size)
            }
            .onEnded { _ in
                draggingIndex = nil
            }
    }

    private func hitTest(_ location: CGPoint, in size: CGSize) -> Int? {
        var best: (index: Int, distance: CGFloat)? = nil
        for (idx, pt) in points.enumerated() {
            let cp = canvasPoint(from: pt, in: size)
            let dx = cp.x - location.x
            let dy = cp.y - location.y
            let dist = (dx * dx + dy * dy).squareRoot()
            if dist <= Self.hitRadius {
                if best == nil || dist < best!.distance {
                    best = (idx, dist)
                }
            }
        }
        return best?.index
    }

    // MARK: - Mutation

    private func addPoint(_ point: [Double]) {
        var newPts = points
        newPts.append(point)
        newPts.sort { $0[0] < $1[0] }
        if let inserted = newPts.firstIndex(where: { $0[0] == point[0] && $0[1] == point[1] }) {
            draggingIndex = inserted
        }
        // Cap to a reasonable number per the schema (PLAN.md §5: 2..16).
        if newPts.count > 16 {
            newPts = Array(newPts.prefix(16))
        }
        document.recipe.operations.toneCurve.rgb = newPts
    }

    private func updatePoint(at index: Int, to canvasLocation: CGPoint, in size: CGSize) {
        var newPts = points
        guard index < newPts.count else { return }
        let raw = imagePoint(from: canvasLocation, in: size)
        var x = raw[0]
        let y = raw[1]
        if index == 0 {
            x = 0
        } else if index == newPts.count - 1 {
            x = 1
        } else {
            let minX = newPts[index - 1][0] + 0.001
            let maxX = newPts[index + 1][0] - 0.001
            x = min(maxX, max(minX, x))
        }
        newPts[index] = [x, y]
        document.recipe.operations.toneCurve.rgb = newPts
    }

    private func setCurve(_ pts: [[Double]]) {
        document.recipe.operations.toneCurve.rgb = pts
        draggingIndex = nil
    }

    // MARK: - Coordinates

    private func canvasPoint(from imagePoint: [Double], in size: CGSize) -> CGPoint {
        CGPoint(
            x: CGFloat(imagePoint[0]) * size.width,
            y: (1 - CGFloat(imagePoint[1])) * size.height
        )
    }

    private func imagePoint(from canvasPoint: CGPoint, in size: CGSize) -> [Double] {
        let x = max(0, min(1, Double(canvasPoint.x / max(1, size.width))))
        let y = max(0, min(1, Double(1 - canvasPoint.y / max(1, size.height))))
        return [x, y]
    }
}
