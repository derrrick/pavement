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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("HSL").font(.headline)
                Spacer()
                Button("Reset") {
                    document.recipe.operations.hsl = HSLOp()
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Picker("Channel", selection: $mode) {
                ForEach(Mode.allCases) { m in Text(m.rawValue).tag(m) }
            }
            .pickerStyle(.segmented)

            ForEach(Array(bands.enumerated()), id: \.offset) { _, band in
                BandSlider(
                    label: band.0,
                    color: band.2,
                    value: bandBinding(keyPath: band.1)
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

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
            Text(label)
                .font(.caption)
                .frame(width: 56, alignment: .leading)
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
        }
    }
}
