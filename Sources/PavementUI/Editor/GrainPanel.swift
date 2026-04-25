import SwiftUI
import PavementCore

struct GrainPanel: View {
    @Bindable var document: PavementDocument

    private let typeLabels: [(String, String)] = [
        (GrainOp.typeCubic,      "Cubic"),
        (GrainOp.typeTabular,    "Tabular"),
        (GrainOp.typeNewsprint,  "Newsprint"),
        (GrainOp.typeSilverRich, "Silver Rich"),
        (GrainOp.typeSoft,       "Soft"),
        (GrainOp.typePlate,      "Plate")
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
                .frame(width: 130)
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
        case GrainOp.typeCubic:      return "Classic silver-halide grain — sharp, isotropic."
        case GrainOp.typeTabular:    return "T-grain (Kodak T-Max style) — flatter, slightly elongated."
        case GrainOp.typeNewsprint:  return "High-contrast binary grain reading like newsprint."
        case GrainOp.typeSilverRich: return "Heavy silver content — Ilford Delta 3200 vibe."
        case GrainOp.typeSoft:       return "Diffused organic grain that blends into the image."
        case GrainOp.typePlate:      return "Wet-plate collodion — large, blotchy structures."
        default:                     return ""
        }
    }
}
