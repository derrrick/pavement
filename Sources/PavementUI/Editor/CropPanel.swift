import SwiftUI
import PavementCore

struct CropPanel: View {
    @Bindable var document: PavementDocument

    private static let aspectChoices: [String] = ["free", "1:1", "3:2", "4:5", "16:9"]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Crop").font(.headline)
                Spacer()
                Toggle("On", isOn: Binding(
                    get: { document.recipe.operations.crop.enabled },
                    set: { document.recipe.operations.crop.enabled = $0 }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
                Button("Reset") {
                    document.recipe.operations.crop = CropOp()
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            HStack {
                Text("Aspect").font(.callout)
                Spacer()
                Picker("Aspect", selection: aspectBinding) {
                    ForEach(Self.aspectChoices, id: \.self) { a in
                        Text(a).tag(a)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 100)
            }

            slider("X",      keyPath: \.x, range: 0...1, step: 0.005, format: "%.3f")
            slider("Y",      keyPath: \.y, range: 0...1, step: 0.005, format: "%.3f")
            slider("Width",  keyPath: \.w, range: 0.05...1, step: 0.005, format: "%.3f", onChange: enforceAspectFromWidth)
            slider("Height", keyPath: \.h, range: 0.05...1, step: 0.005, format: "%.3f", onChange: enforceAspectFromHeight)
            slider("Rotate", keyPath: \.rotation, range: -45...45, step: 0.1, format: "%+.1f°")
        }
    }

    private var aspectBinding: Binding<String> {
        Binding(
            get: { document.recipe.operations.crop.aspect },
            set: { newValue in
                document.recipe.operations.crop.aspect = newValue
                if let ratio = CropFilter.aspectRatio(newValue) {
                    enforceAspect(ratio: ratio, drivingHeight: false)
                }
            }
        )
    }

    private func slider(
        _ label: String,
        keyPath: WritableKeyPath<CropOp, Double>,
        range: ClosedRange<Double>,
        step: Double,
        format: String,
        onChange: (() -> Void)? = nil
    ) -> some View {
        HStack {
            Text(label).font(.callout).frame(width: 56, alignment: .leading)
            Slider(
                value: Binding(
                    get: { document.recipe.operations.crop[keyPath: keyPath] },
                    set: {
                        document.recipe.operations.crop[keyPath: keyPath] = $0
                        onChange?()
                    }
                ),
                in: range,
                step: step
            )
            Text(String(format: format, document.recipe.operations.crop[keyPath: keyPath]))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .trailing)
        }
    }

    private func enforceAspectFromWidth() {
        guard let ratio = CropFilter.aspectRatio(document.recipe.operations.crop.aspect) else { return }
        enforceAspect(ratio: ratio, drivingHeight: true)
    }

    private func enforceAspectFromHeight() {
        guard let ratio = CropFilter.aspectRatio(document.recipe.operations.crop.aspect) else { return }
        enforceAspect(ratio: ratio, drivingHeight: false)
    }

    /// `drivingHeight = true` means width was changed; recompute height.
    /// Otherwise height was changed and we recompute width.
    /// `ratio = width / height`.
    private func enforceAspect(ratio: CGFloat, drivingHeight: Bool) {
        let crop = document.recipe.operations.crop
        if drivingHeight {
            let newH = crop.w / Double(ratio)
            document.recipe.operations.crop.h = max(0.05, min(1, newH))
        } else {
            let newW = crop.h * Double(ratio)
            document.recipe.operations.crop.w = max(0.05, min(1, newW))
        }
    }
}
