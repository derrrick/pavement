import SwiftUI

/// Rule-of-thirds grid overlay rendered on top of the canvas. Two
/// vertical and two horizontal lines at the 1/3 and 2/3 marks.
struct GridOverlay: View {
    var body: some View {
        Canvas { ctx, size in
            var path = Path()
            // Vertical
            path.move(to: CGPoint(x: size.width / 3, y: 0))
            path.addLine(to: CGPoint(x: size.width / 3, y: size.height))
            path.move(to: CGPoint(x: 2 * size.width / 3, y: 0))
            path.addLine(to: CGPoint(x: 2 * size.width / 3, y: size.height))
            // Horizontal
            path.move(to: CGPoint(x: 0, y: size.height / 3))
            path.addLine(to: CGPoint(x: size.width, y: size.height / 3))
            path.move(to: CGPoint(x: 0, y: 2 * size.height / 3))
            path.addLine(to: CGPoint(x: size.width, y: 2 * size.height / 3))
            ctx.stroke(path, with: .color(.white.opacity(0.45)),
                       style: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
        }
        .allowsHitTesting(false)
    }
}
