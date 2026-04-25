import SwiftUI
import PavementCore

struct BasicAdjustmentsPanel: View {
    @Bindable var document: PavementDocument

    var body: some View {
        ScrollView {
            BasicAdjustmentsPanelInline(document: document)
                .padding(12)
        }
        .frame(minWidth: 240)
    }
}

struct BasicAdjustmentsPanelInline: View {
    @Bindable var document: PavementDocument

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            whiteBalanceSection
            Divider()
            exposureSection
            Divider()
            toneSection
        }
    }

    // MARK: - White Balance

    private var whiteBalanceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("White Balance", reset: {
                document.recipe.operations.whiteBalance = WhiteBalanceOp()
            })

            Picker("Mode", selection: Binding(
                get: { document.recipe.operations.whiteBalance.mode },
                set: { document.recipe.operations.whiteBalance.mode = $0 }
            )) {
                Text("As shot").tag(WhiteBalanceOp.asShot)
                Text("Custom").tag(WhiteBalanceOp.custom)
            }
            .pickerStyle(.segmented)

            slider(
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
            slider(
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

    // MARK: - Exposure

    private var exposureSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Exposure", reset: {
                document.recipe.operations.exposure = ExposureOp()
            })

            slider(
                label: "EV",
                value: $document.recipe.operations.exposure.ev,
                range: Clamping.Range.exposureEV,
                step: 0.05,
                format: "%+.2f"
            )
        }
    }

    // MARK: - Tone

    private var toneSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Tone", reset: {
                document.recipe.operations.tone = ToneOp()
            })

            intSlider(label: "Contrast",   keyPath: \.contrast)
            intSlider(label: "Highlights", keyPath: \.highlights)
            intSlider(label: "Shadows",    keyPath: \.shadows)
            intSlider(label: "Whites",     keyPath: \.whites)
            intSlider(label: "Blacks",     keyPath: \.blacks)
            intSlider(label: "Recovery",   keyPath: \.highlightRecovery,
                      range: Clamping.Range.highlightRecovery)
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, reset: @escaping () -> Void) -> some View {
        HStack {
            Text(title).font(.headline)
            Spacer()
            Button("Reset", action: reset)
                .buttonStyle(.borderless)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func slider(
        label: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        format: String,
        defaultValue: Double = 0,
        isEnabled: Bool = true
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label).font(.callout)
                Spacer()
                Text(String(format: format, value.wrappedValue))
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .onTapGesture(count: 2) { value.wrappedValue = defaultValue }
                    .help("Double-click to reset")
            }
            Slider(value: value, in: range, step: step)
                .disabled(!isEnabled)
        }
    }

    private func intSlider(
        label: String,
        keyPath: WritableKeyPath<ToneOp, Int>,
        range: ClosedRange<Int> = Clamping.Range.signedHundred,
        defaultValue: Int = 0
    ) -> some View {
        slider(
            label: label,
            value: Binding(
                get: { Double(document.recipe.operations.tone[keyPath: keyPath]) },
                set: { document.recipe.operations.tone[keyPath: keyPath] = Int($0.rounded()) }
            ),
            range: Double(range.lowerBound)...Double(range.upperBound),
            step: 1,
            format: "%+.0f",
            defaultValue: Double(defaultValue)
        )
    }
}
