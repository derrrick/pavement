import SwiftUI
import PavementCore

struct GrainPanel: View {
    @Bindable var document: PavementDocument

    private let typeLabels: [(String, String)] = [
        (GrainOp.typeFine,       "Fine"),
        (GrainOp.typeCubic,      "Cubic (T-MAX)"),
        (GrainOp.typeTabular,    "Tabular"),
        (GrainOp.typeSilverRich, "Silver Rich"),
        (GrainOp.typeSoft,       "Soft"),
        (GrainOp.typeHarsh,      "Harsh (Pushed)"),
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
        case GrainOp.typeFine:       return "Modern digital grain — uniform per-pixel, crisp."
        case GrainOp.typeCubic:      return "T-MAX cubic crystals — sharp, well-defined grain."
        case GrainOp.typeTabular:    return "Anisotropic platelet — slightly elongated grain."
        case GrainOp.typeSilverRich: return "Dense silver content — heavy, deeply-textured."
        case GrainOp.typeSoft:       return "Diffuse portrait grain — atmospheric, low-contrast."
        case GrainOp.typeHarsh:      return "Pushed film — extreme contrast, gritty clumps."
        default:                     return ""
        }
    }
}
