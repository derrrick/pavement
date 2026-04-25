import SwiftUI
import PavementCore

struct HSLPanel: View {
    @Bindable var document: PavementDocument
    @State private var mode: Mode = .hue

    enum Mode: String, CaseIterable, Identifiable {
        case hue = "Hue"
        case saturation = "Sat"
        case luminance = "Lum"
        var id: String { rawValue }
    }

    /// (label, key path, swatch color)
    private var bands: [(String, WritableKeyPath<HSLOp, HSLBand>, Color)] {
        [
            ("Red",     \.red,     .red),
            ("Orange",  \.orange,  .orange),
            ("Yellow",  \.yellow,  .yellow),
            ("Green",   \.green,   .green),
            ("Aqua",    \.aqua,    Color(red: 0.4, green: 0.85, blue: 0.9)),
            ("Blue",    \.blue,    .blue),
            ("Purple",  \.purple,  .purple),
            ("Magenta", \.magenta, Color(red: 0.95, green: 0.3, blue: 0.7)),
        ]
    }

    private var isModified: Bool {
        !HSLFilter.isIdentity(document.recipe.operations.hsl)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if document.previewIsolation != nil {
                HStack {
                    Spacer()
                    Button("Show All") { document.previewIsolation = nil }
                        .buttonStyle(.borderless)
                        .font(.caption)
                }
            }

            HueBandsVisualizer(
                hsl: document.recipe.operations.hsl,
                isolatedIndex: document.previewIsolation,
                onTap: { index in
                    if document.previewIsolation == index {
                        document.previewIsolation = nil
                    } else {
                        document.previewIsolation = index
                    }
                }
            )
            .frame(height: 26)

            Picker("Channel", selection: $mode) {
                ForEach(Mode.allCases) { m in Text(m.rawValue).tag(m) }
            }
            .pickerStyle(.segmented)

            ForEach(Array(bands.enumerated()), id: \.offset) { idx, band in
                BandSlider(
                    label: band.0,
                    color: band.2,
                    value: bandBinding(keyPath: band.1),
                    isIsolated: document.previewIsolation == idx
                )
            }
        }
    }

    private func bandBinding(keyPath: WritableKeyPath<HSLOp, HSLBand>) -> Binding<Int> {
        Binding(
            get: {
                let band = document.recipe.operations.hsl[keyPath: keyPath]
                switch mode {
                case .hue:        return band.h
                case .saturation: return band.s
                case .luminance:  return band.l
                }
            },
            set: { newValue in
                switch mode {
                case .hue:        document.recipe.operations.hsl[keyPath: keyPath].h = newValue
                case .saturation: document.recipe.operations.hsl[keyPath: keyPath].s = newValue
                case .luminance:  document.recipe.operations.hsl[keyPath: keyPath].l = newValue
                }
            }
        )
    }
}

private struct BandSlider: View {
    let label: String
    let color: Color
    @Binding var value: Int
    var defaultValue: Int = 0
    var isIsolated: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
                .overlay(
                    Circle().stroke(Color.accentColor, lineWidth: isIsolated ? 2 : 0)
                )
            Text(label)
                .font(.caption)
                .frame(width: 56, alignment: .leading)
                .foregroundStyle(isIsolated ? .primary : .primary)
                .fontWeight(isIsolated ? .semibold : .regular)
            Slider(
                value: Binding(
                    get: { Double(value) },
                    set: { value = Int($0.rounded()) }
                ),
                in: -100...100,
                step: 1
            )
            Text("\(value > 0 ? "+" : "")\(value)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .trailing)
                .onTapGesture(count: 2) { value = defaultValue }
                .help("Double-click to reset")
        }
    }
}

/// Capture-One-style visualizer: a horizontal hue spectrum where each
/// band's center is marked with a tappable handle. Tap a handle to
/// isolate that band on the canvas (everything else desaturates).
private struct HueBandsVisualizer: View {
    let hsl: HSLOp
    let isolatedIndex: Int?
    let onTap: (Int) -> Void

    private static let bandCenters: [Double] = [0, 30, 60, 120, 180, 240, 280, 320]

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                spectrum
                    .frame(width: geo.size.width, height: geo.size.height)
                ForEach(Array(Self.bandCenters.enumerated()), id: \.offset) { index, hue in
                    let x = CGFloat(hue) / 360 * geo.size.width
                    let band = bandValues(at: index)
                    let active = (band.h != 0 || band.s != 0 || band.l != 0)
                    let isolated = isolatedIndex == index
                    BandMarker(active: active, isolated: isolated)
                        .position(x: x, y: geo.size.height / 2)
                        .onTapGesture {
                            onTap(index)
                        }
                }
            }
        }
        .help("Click a band marker to isolate that color range on the canvas")
    }

    private var spectrum: some View {
        Canvas { ctx, size in
            let bands = 60
            for i in 0..<bands {
                let x = CGFloat(i) / CGFloat(bands) * size.width
                let nextX = CGFloat(i + 1) / CGFloat(bands) * size.width
                let hue = Double(i) / Double(bands)
                let color = Color(hue: hue, saturation: 0.85, brightness: 1.0)
                ctx.fill(
                    Path(CGRect(x: x, y: 0, width: nextX - x + 0.5, height: size.height)),
                    with: .color(color)
                )
            }
            let border = Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 4)
            ctx.stroke(border, with: .color(.white.opacity(0.15)), lineWidth: 0.5)
        }
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }

    private func bandValues(at index: Int) -> HSLBand {
        switch index {
        case 0: return hsl.red
        case 1: return hsl.orange
        case 2: return hsl.yellow
        case 3: return hsl.green
        case 4: return hsl.aqua
        case 5: return hsl.blue
        case 6: return hsl.purple
        case 7: return hsl.magenta
        default: return HSLBand()
        }
    }
}

private struct BandMarker: View {
    let active: Bool
    let isolated: Bool

    var body: some View {
        let size: CGFloat = isolated ? 14 : (active ? 10 : 7)
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: size, height: size)
                .shadow(color: .black.opacity(0.5), radius: 1)
            if isolated {
                Circle()
                    .stroke(Color.accentColor, lineWidth: 2)
                    .frame(width: size, height: size)
            } else if active {
                Circle()
                    .stroke(Color.accentColor.opacity(0.5), lineWidth: 1.5)
                    .frame(width: size, height: size)
            }
        }
        .contentShape(Circle().scale(2.5))
    }
}
