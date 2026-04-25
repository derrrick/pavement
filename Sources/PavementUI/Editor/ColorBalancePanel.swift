import SwiftUI
import PavementCore

/// Capture-One-inspired Color Balance with hue/sat color wheels for
/// shadows, midtones, and highlights, plus a Master tab that drives all
/// three at once. Each wheel has a draggable point (hue + saturation)
/// and a luminance slider below.
struct ColorBalancePanel: View {
    @Bindable var document: PavementDocument
    @State private var mode: Mode = .threeWay

    enum Mode: String, CaseIterable, Identifiable {
        case master = "Master"
        case threeWay = "3-Way"
        case shadow = "Shadow"
        case midtone = "Midtone"
        case highlight = "Highlight"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Mode", selection: $mode) {
                ForEach(Mode.allCases) { m in Text(m.rawValue).tag(m) }
            }
            .pickerStyle(.segmented)

            switch mode {
            case .master:    masterView
            case .threeWay:  threeWayView
            case .shadow:    singleView(label: "Shadow", wheel: shadowsBinding)
            case .midtone:   singleView(label: "Midtone", wheel: midtonesBinding)
            case .highlight: singleView(label: "Highlight", wheel: highlightsBinding)
            }

            Divider()

            HStack {
                Text("Balance").font(.caption)
                Slider(
                    value: Binding(
                        get: { Double(document.recipe.operations.colorGrading.balance) },
                        set: { document.recipe.operations.colorGrading.balance = Int($0.rounded()) }
                    ),
                    in: -100...100,
                    step: 1
                )
                Text("\(document.recipe.operations.colorGrading.balance)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 32)
                    .onTapGesture(count: 2) { document.recipe.operations.colorGrading.balance = 0 }
            }
        }
    }

    // MARK: - Mode contents

    private var masterView: some View {
        VStack {
            ColorWheelView(wheel: globalBinding)
                .frame(width: 200, height: 200)
                .padding(.top, 8)
            Text("Affects all tonal ranges")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private var threeWayView: some View {
        VStack(spacing: 12) {
            HStack {
                Spacer()
                wheelTile(label: "Midtone", binding: midtonesBinding, size: 130)
                Spacer()
            }
            HStack(spacing: 12) {
                wheelTile(label: "Shadow", binding: shadowsBinding, size: 130)
                wheelTile(label: "Highlight", binding: highlightsBinding, size: 130)
            }
        }
    }

    private func singleView(label: String, wheel: Binding<GradingWheel>) -> some View {
        VStack {
            ColorWheelView(wheel: wheel)
                .frame(width: 200, height: 200)
                .padding(.top, 8)
            Text(label).font(.caption)
        }
        .frame(maxWidth: .infinity)
    }

    private func wheelTile(label: String, binding: Binding<GradingWheel>, size: CGFloat) -> some View {
        VStack(spacing: 4) {
            ColorWheelView(wheel: binding)
                .frame(width: size, height: size)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }

    // MARK: - Bindings

    private var shadowsBinding: Binding<GradingWheel> {
        Binding(
            get: { document.recipe.operations.colorGrading.shadows },
            set: { document.recipe.operations.colorGrading.shadows = $0 }
        )
    }
    private var midtonesBinding: Binding<GradingWheel> {
        Binding(
            get: { document.recipe.operations.colorGrading.midtones },
            set: { document.recipe.operations.colorGrading.midtones = $0 }
        )
    }
    private var highlightsBinding: Binding<GradingWheel> {
        Binding(
            get: { document.recipe.operations.colorGrading.highlights },
            set: { document.recipe.operations.colorGrading.highlights = $0 }
        )
    }
    private var globalBinding: Binding<GradingWheel> {
        Binding(
            get: { document.recipe.operations.colorGrading.global },
            set: { document.recipe.operations.colorGrading.global = $0 }
        )
    }
}

/// One color-balance wheel. Drag inside the ring to set (hue, saturation);
/// the luminance arc on the right edge runs vertically from -100 (bottom)
/// to +100 (top).
struct ColorWheelView: View {
    @Binding var wheel: GradingWheel

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let outerRadius = side / 2
            let ringInset: CGFloat = 6
            let innerRadius = outerRadius - 16
            let dotRadius = innerRadius - 4

            ZStack {
                hueRing
                    .frame(width: side, height: side)
                Circle()
                    .fill(Color(white: 0.10))
                    .frame(width: innerRadius * 2 - ringInset * 2,
                           height: innerRadius * 2 - ringInset * 2)
                Circle()
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    .frame(width: innerRadius * 2 - ringInset * 2,
                           height: innerRadius * 2 - ringInset * 2)

                // Center crosshair at sat=0
                Circle()
                    .stroke(Color.white.opacity(0.22), lineWidth: 1)
                    .frame(width: 12, height: 12)
                    .position(x: center.x, y: center.y)

                // Position dot
                positionDot(center: center, dotRadius: dotRadius)
            }
            .contentShape(Rectangle())
            .gesture(dragGesture(in: geo.size))
            .onTapGesture(count: 2) {
                wheel.hue = 0
                wheel.sat = 0
            }
            .help("Drag to set hue + saturation. Double-click to reset.")
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var hueRing: some View {
        Circle()
            .strokeBorder(
                AngularGradient(
                    gradient: Gradient(colors: [
                        Color(hue: 0/360, saturation: 1, brightness: 1),
                        Color(hue: 60/360, saturation: 1, brightness: 1),
                        Color(hue: 120/360, saturation: 1, brightness: 1),
                        Color(hue: 180/360, saturation: 1, brightness: 1),
                        Color(hue: 240/360, saturation: 1, brightness: 1),
                        Color(hue: 300/360, saturation: 1, brightness: 1),
                        Color(hue: 1, saturation: 1, brightness: 1)
                    ]),
                    center: .center,
                    startAngle: .degrees(0),
                    endAngle: .degrees(360)
                ),
                lineWidth: 12
            )
    }

    private func positionDot(center: CGPoint, dotRadius: CGFloat) -> some View {
        let saturation = max(0, min(1, Double(wheel.sat) / 100.0))
        let r = dotRadius * CGFloat(saturation)
        let theta = Double(wheel.hue) * .pi / 180
        let x = center.x + r * CGFloat(cos(theta))
        let y = center.y - r * CGFloat(sin(theta))
        return ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 14, height: 14)
                .shadow(color: .black.opacity(0.5), radius: 1)
            Circle()
                .stroke(Color(hue: Double(wheel.hue) / 360, saturation: 1, brightness: 1),
                        lineWidth: 2)
                .frame(width: 14, height: 14)
        }
        .position(x: x, y: y)
    }

    private func dragGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = min(size.width, size.height) / 2 - 20
                let dx = value.location.x - center.x
                let dy = center.y - value.location.y // SwiftUI Y is flipped
                let r = sqrt(dx * dx + dy * dy)
                let normR = min(1, r / radius)

                if normR < 0.05 {
                    wheel.sat = 0
                    return
                }
                let theta = atan2(dy, dx) * 180 / .pi
                let hue = (theta + 360).truncatingRemainder(dividingBy: 360)
                wheel.hue = Int(hue.rounded())
                wheel.sat = Int((normR * 100).rounded())
            }
    }
}
