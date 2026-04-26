import SwiftUI
import PavementCore

struct GrainPanel: View {
    @Bindable var document: PavementDocument

    private let typeLabels: [(String, String)] = [
        (GrainOp.typeFine,       "Fine Grain"),
        (GrainOp.typeSilverRich, "Silver Rich"),
        (GrainOp.typeSoft,       "Soft Grain"),
        (GrainOp.typeCubic,      "Cubic Grains"),
        (GrainOp.typeTabular,    "Tabular Grains"),
        (GrainOp.typeHarsh,      "Harsh Grain"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Type").font(.caption)
                Spacer()
                Picker("Type", selection: Binding(
                    get: { document.recipe.operations.grain.type },
                    set: { document.recipe.operations.grain.type = $0 }
                )) {
                    ForEach(typeLabels, id: \.0) { tag, label in
                        Text(label).tag(tag)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 150)
            }

            SliderRow(
                label: "Amount",
                value: intBinding(\.amount),
                range: 0...100,
                step: 1,
                format: "%.0f",
                defaultValue: 0
            )
            SliderRow(
                label: "Size",
                value: intBinding(\.size),
                range: 0...100,
                step: 1,
                format: "%.0f",
                defaultValue: 25
            )
            SliderRow(
                label: "Roughness",
                value: intBinding(\.roughness),
                range: 0...100,
                step: 1,
                format: "%.0f",
                defaultValue: 50
            )

            Text(typeDescription(for: document.recipe.operations.grain.type))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private func intBinding(_ keyPath: WritableKeyPath<GrainOp, Int>) -> Binding<Double> {
        Binding(
            get: { Double(document.recipe.operations.grain[keyPath: keyPath]) },
            set: { document.recipe.operations.grain[keyPath: keyPath] = Int($0.rounded()) }
        )
    }

    private func typeDescription(for type: String) -> String {
        switch type {
        case GrainOp.typeFine:       return "Standard modern digital grain — very uniform."
        case GrainOp.typeSilverRich: return "Dense silver halide black-and-white film — deep, textured."
        case GrainOp.typeSoft:       return "Diffused, less sharp texture — often used for portraits."
        case GrainOp.typeCubic:      return "Modern T-Grain (Kodak T-MAX) — flat tabular crystals, sharp."
        case GrainOp.typeTabular:    return "Distinct platelet shape — similar to cubic, more elongated."
        case GrainOp.typeHarsh:      return "High-contrast, gritty grain from pushed (high-ISO) film."
        default:                     return ""
        }
    }
}
