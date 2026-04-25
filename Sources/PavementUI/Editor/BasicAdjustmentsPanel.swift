import SwiftUI
import PavementCore

/// Slider rows used by the editor's three "basic" sections.
/// Each section ships as a separate view so it can live inside its own
/// CollapsibleSection in the side panel.

struct WhiteBalancePanel: View {
    @Bindable var document: PavementDocument

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Mode", selection: Binding(
                get: { document.recipe.operations.whiteBalance.mode },
                set: { document.recipe.operations.whiteBalance.mode = $0 }
            )) {
                Text("As shot").tag(WhiteBalanceOp.asShot)
                Text("Custom").tag(WhiteBalanceOp.custom)
            }
            .pickerStyle(.segmented)

            SliderRow(
                label: "Temp",
                value: Binding(
                    get: { Double(document.recipe.operations.whiteBalance.temp) },
                    set: { document.recipe.operations.whiteBalance.temp = Int($0) }
                ),
                range: Double(Clamping.Range.temperature.lowerBound)...Double(Clamping.Range.temperature.upperBound),
                step: 50,
                format: "%.0fK",
                defaultValue: 5500,
                isEnabled: document.recipe.operations.whiteBalance.mode == WhiteBalanceOp.custom
            )
            SliderRow(
                label: "Tint",
                value: Binding(
                    get: { Double(document.recipe.operations.whiteBalance.tint) },
                    set: { document.recipe.operations.whiteBalance.tint = Int($0) }
                ),
                range: Double(Clamping.Range.tint.lowerBound)...Double(Clamping.Range.tint.upperBound),
                step: 1,
                format: "%.0f",
                defaultValue: 0,
                isEnabled: document.recipe.operations.whiteBalance.mode == WhiteBalanceOp.custom
            )
        }
    }
}

struct ExposurePanel: View {
    @Bindable var document: PavementDocument

    var body: some View {
        SliderRow(
            label: "EV",
            value: $document.recipe.operations.exposure.ev,
            range: Clamping.Range.exposureEV,
            step: 0.05,
            format: "%+.2f",
            defaultValue: 0
        )
    }
}

struct TonePanel: View {
    @Bindable var document: PavementDocument

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            intRow("Contrast",   keyPath: \.contrast)
            intRow("Highlights", keyPath: \.highlights)
            intRow("Shadows",    keyPath: \.shadows)
            intRow("Whites",     keyPath: \.whites)
            intRow("Blacks",     keyPath: \.blacks)
            intRow("Recovery",   keyPath: \.highlightRecovery,
                   range: Clamping.Range.highlightRecovery)
        }
    }

    private func intRow(
        _ label: String,
        keyPath: WritableKeyPath<ToneOp, Int>,
        range: ClosedRange<Int> = Clamping.Range.signedHundred
    ) -> some View {
        SliderRow(
            label: label,
            value: Binding(
                get: { Double(document.recipe.operations.tone[keyPath: keyPath]) },
                set: { document.recipe.operations.tone[keyPath: keyPath] = Int($0.rounded()) }
            ),
            range: Double(range.lowerBound)...Double(range.upperBound),
            step: 1,
            format: "%+.0f",
            defaultValue: 0
        )
    }
}

/// Reusable slider row with label, slider, value readout, and a
/// double-click-to-default behavior on the value text.
struct SliderRow: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: String
    let defaultValue: Double
    var isEnabled: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label).font(.callout)
                Spacer()
                Text(String(format: format, value))
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .onTapGesture(count: 2) { value = defaultValue }
                    .help("Double-click to reset")
            }
            Slider(value: $value, in: range, step: step)
                .disabled(!isEnabled)
        }
    }
}
