import SwiftUI
import PavementCore

struct CropPanel: View {
    @Bindable var document: PavementDocument

    private static let aspectChoices: [String] = ["free", "1:1", "3:2", "4:5", "16:9"]

    private var isModified: Bool {
        document.recipe.operations.crop != CropOp()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Spacer()
                Toggle("On", isOn: Binding(
                    get: { document.recipe.operations.crop.enabled },
                    set: { document.recipe.operations.crop.enabled = $0 }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
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

            slider("X",      keyPath: \.x, range: 0...1, step: 0.005, format: "%.3f", defaultValue: 0)
            slider("Y",      keyPath: \.y, range: 0...1, step: 0.005, format: "%.3f", defaultValue: 0)
            slider("Width",  keyPath: \.w, range: 0.05...1, step: 0.005, format: "%.3f", defaultValue: 1, onChange: enforceAspectFromWidth)
            slider("Height", keyPath: \.h, range: 0.05...1, step: 0.005, format: "%.3f", defaultValue: 1, onChange: enforceAspectFromHeight)
            slider("Rotate", keyPath: \.rotation, range: -45...45, step: 0.1, format: "%+.1f°", defaultValue: 0)
        }
    }

    private var aspectBinding: Binding<String> {
        Binding(
            get: { document.recipe.operations.crop.aspect },
            set: { newValue in
                document.recipe.operations.crop.aspect = newValue
                if let ratio = CropFilter.aspectRatio(newValue) {
                    enforceAspect(targetAspect: ratio, drivingHeight: false)
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
        defaultValue: Double,
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
                .onTapGesture(count: 2) {
                    document.recipe.operations.crop[keyPath: keyPath] = defaultValue
                    onChange?()
                }
                .help("Double-click to reset")
        }
    }

    private func enforceAspectFromWidth() {
        guard let ratio = CropFilter.aspectRatio(document.recipe.operations.crop.aspect) else { return }
        enforceAspect(targetAspect: ratio, drivingHeight: true)
    }

    private func enforceAspectFromHeight() {
        guard let ratio = CropFilter.aspectRatio(document.recipe.operations.crop.aspect) else { return }
        enforceAspect(targetAspect: ratio, drivingHeight: false)
    }

    /// `drivingHeight = true` means width was changed; recompute height.
    /// Otherwise height was changed and we recompute width.
    ///
    /// Crop dimensions are normalized to source extent, so the *output*
    /// aspect after cropping is `(w * sourceW) / (h * sourceH) =
    /// (w / h) * sourceAspect`. To get a target output aspect, the
    /// normalized aspect must be `targetAspect / sourceAspect`.
    private func enforceAspect(targetAspect: CGFloat, drivingHeight: Bool) {
        let crop = document.recipe.operations.crop
        let sourceAspect = document.sourceAspectRatio
        let normalized = targetAspect / sourceAspect
        if drivingHeight {
            let newH = crop.w / Double(normalized)
            let clamped = max(0.05, min(1, newH))
            document.recipe.operations.crop.h = clamped
            // If clamping changed h, also clamp w so the output aspect stays correct
            if clamped == 1 || clamped == 0.05 {
                document.recipe.operations.crop.w = clamped * Double(normalized)
            }
        } else {
            let newW = crop.h * Double(normalized)
            let clamped = max(0.05, min(1, newW))
            document.recipe.operations.crop.w = clamped
            if clamped == 1 || clamped == 0.05 {
                document.recipe.operations.crop.h = clamped / Double(normalized)
            }
        }
    }
}
