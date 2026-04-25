import SwiftUI
import PavementCore

struct DetailPanel: View {
    @Bindable var document: PavementDocument

    private var isModified: Bool {
        let op = document.recipe.operations.detail
        return op != DetailOp()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Text("Detail").font(.headline)
                if isModified {
                    Circle().fill(Color.accentColor).frame(width: 6, height: 6)
                }
                Spacer()
                Button("Reset") {
                    document.recipe.operations.detail = DetailOp()
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Sharpening")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                slider(
                    label: "Amount",
                    keyPath: \.sharpAmount,
                    range: 0...150,
                    step: 1,
                    format: "%d",
                    defaultValue: 30
                )
                slider(
                    label: "Radius",
                    keyPath: \.sharpRadius,
                    range: 0.5...3.0,
                    step: 0.05,
                    format: "%.2f",
                    defaultValue: 1.0
                )
                slider(
                    label: "Masking",
                    keyPath: \.sharpMasking,
                    range: 0...100,
                    step: 1,
                    format: "%d",
                    defaultValue: 0
                )
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Noise Reduction")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                slider(
                    label: "Luminance",
                    keyPath: \.noiseLuma,
                    range: 0...100,
                    step: 1,
                    format: "%d",
                    defaultValue: 0
                )
                slider(
                    label: "Color",
                    keyPath: \.noiseColor,
                    range: 0...100,
                    step: 1,
                    format: "%d",
                    defaultValue: 25
                )
            }
        }
    }

    private func slider<V: BinaryInteger>(
        label: String,
        keyPath: WritableKeyPath<DetailOp, V>,
        range: ClosedRange<Double>,
        step: Double,
        format: String,
        defaultValue: V
    ) -> some View {
        HStack {
            Text(label).font(.caption).frame(width: 76, alignment: .leading)
            Slider(
                value: Binding(
                    get: { Double(document.recipe.operations.detail[keyPath: keyPath]) },
                    set: { document.recipe.operations.detail[keyPath: keyPath] = V($0.rounded()) }
                ),
                in: range,
                step: step
            )
            Text(String(format: format, Int(document.recipe.operations.detail[keyPath: keyPath])))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .trailing)
                .onTapGesture(count: 2) {
                    document.recipe.operations.detail[keyPath: keyPath] = defaultValue
                }
                .help("Double-click to reset")
        }
    }

    /// Specialised double-valued slider for sharpRadius (the only Double field).
    private func slider(
        label: String,
        keyPath: WritableKeyPath<DetailOp, Double>,
        range: ClosedRange<Double>,
        step: Double,
        format: String,
        defaultValue: Double
    ) -> some View {
        HStack {
            Text(label).font(.caption).frame(width: 76, alignment: .leading)
            Slider(
                value: Binding(
                    get: { document.recipe.operations.detail[keyPath: keyPath] },
                    set: { document.recipe.operations.detail[keyPath: keyPath] = $0 }
                ),
                in: range,
                step: step
            )
            Text(String(format: format, document.recipe.operations.detail[keyPath: keyPath]))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .trailing)
                .onTapGesture(count: 2) {
                    document.recipe.operations.detail[keyPath: keyPath] = defaultValue
                }
                .help("Double-click to reset")
        }
    }
}
